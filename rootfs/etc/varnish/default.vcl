vcl 4.1;

import std;
import xkey;

# Specify your app nodes here. Use round-robin balancing to add more than one.
backend default {
    .host = "__SHOPWARE_BACKEND_HOST__";
    .port = "__SHOPWARE_BACKEND_PORT__";
}

# ACL for purgers IP. (This needs to contain app server ips)
acl purgers {
    "127.0.0.1";
    "localhost";
    "::1";
}

sub vcl_recv {
    # Handle PURGE
    if (req.method == "PURGE") {
        if (client.ip !~ purgers) {
            return (synth(403, "Forbidden"));
        }
        if (req.http.xkey) {
            set req.http.n-gone = xkey.purge(req.http.xkey);

            return (synth(200, "Invalidated "+req.http.n-gone+" objects"));
        } else {
            return (purge);
        }
    }

    if (req.method == "BAN") {
        if (!client.ip ~ purgers) {
            return (synth(405, "Method not allowed"));
        }

        ban("req.url ~ "+req.url);
        return (synth(200, "BAN URLs containing (" + req.url + ") done."));
    }

    # Only handle relevant HTTP request methods
    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "PATCH" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {
          return (pipe);
    }

    # We only deal with GET and HEAD by default
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Don't cache Authenticate & Authorization
    if (req.http.Authenticate || req.http.Authorization) {
        return (pass);
    }

    # Always pass these paths directly to php without caching
    # Note: virtual URLs might bypass this rule (e.g. /en/checkout)
    if (req.url ~ "^/(checkout|account|admin|api)(/.*)?$") {
        return (pass);
    }

    # Collapse multiple cookie headers into one
    std.collect(req.http.Cookie);

    #  Ignore query strings that are only necessary for the js on the client. Customize as needed.
    if (req.url ~ "(\?|&)(pk_campaign|piwik_campaign|pk_kwd|piwik_kwd|pk_keyword|pixelId|kwid|kw|adid|chl|dv|nk|pa|camid|adgid|cx|ie|cof|siteurl|utm_[a-z]+|_ga|gclid)=") {
        # see rfc3986#section-2.3 "Unreserved Characters" for regex
        set req.url = regsuball(req.url, "(pk_campaign|piwik_campaign|pk_kwd|piwik_kwd|pk_keyword|pixelId|kwid|kw|adid|chl|dv|nk|pa|camid|adgid|cx|ie|cof|siteurl|utm_[a-z]+|_ga|gclid)=[A-Za-z0-9\-\_\.\~]+&?", "");
    }

    set req.url = regsub(req.url, "(\?|\?&|&)$", "");

    # Normalize query arguments
    set req.url = std.querysort(req.url);

    # Set a header announcing Surrogate Capability to the origin
    set req.http.Surrogate-Capability = "shopware=ESI/1.0";

    # Make sure that the client ip is forward to the client.
    if (req.http.x-forwarded-for) {
        set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
    } else {
        set req.http.X-Forwarded-For = client.ip;
    }

    return (hash);
}

sub vcl_hash {
    # Consider Shopware HTTP cache cookies
    if (req.http.cookie ~ "sw-cache-hash=") {
        hash_data("+context=" + regsub(req.http.cookie, "^.*?sw-cache-hash=([^;]*);*.*$", "\1"));
    } elseif (req.http.cookie ~ "sw-currency=") {
        hash_data("+currency=" + regsub(req.http.cookie, "^.*?sw-currency=([^;]*);*.*$", "\1"));
    }
}

sub vcl_hit {
  # Consider client states for response headers
  if (req.http.cookie ~ "sw-states=") {
     set req.http.states = regsub(req.http.cookie, "^.*?sw-states=([^;]*);*.*$", "\1");

     if (req.http.states ~ "logged-in" && obj.http.sw-invalidation-states ~ "logged-in" ) {
        return (pass);
     }

     if (req.http.states ~ "cart-filled" && obj.http.sw-invalidation-states ~ "cart-filled" ) {
        return (pass);
     }
  }
}

sub vcl_backend_response {
    # Serve stale content for three days after object expiration
	# Perform asynchronous revalidation while stale content is served
    set beresp.grace = 3d;

    unset beresp.http.X-Powered-By;
    unset beresp.http.Server;

    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        unset beresp.http.Surrogate-Control;
        set beresp.do_esi = true;
        return (deliver);
    }

    if (bereq.url ~ "\.js$" || beresp.http.content-type ~ "text") {
        set beresp.do_gzip = true;
    }

    if (beresp.ttl > 0s && (bereq.method == "GET" || bereq.method == "HEAD")) {
        unset beresp.http.Set-Cookie;
    }
}

sub vcl_deliver {
    ## we don't want the client to cache
    if (resp.http.Cache-Control !~ "private" && req.url !~ "^/(theme|media|thumbnail|bundles)/") {
        set resp.http.Pragma = "no-cache";
        set resp.http.Expires = "-1";
        set resp.http.Cache-Control = "no-store, no-cache, must-revalidate, max-age=0";
    }

    # invalidation headers are only for internal use
    unset resp.http.sw-invalidation-states;
    unset resp.http.xkey;
    unset resp.http.X-Varnish;
    unset resp.http.Via;
    unset resp.http.Link;
}
