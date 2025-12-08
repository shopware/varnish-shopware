vcl 4.1;

import std;
import xkey;
import cookie;

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
    __SHOPWARE_ALLOWED_PURGER_IP__;
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
        if (client.ip !~ purgers) {
            return (synth(403, "Forbidden"));
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

    if (req.http.Authorization) {
        return (pass);
    }

    # We only deal with GET and HEAD by default
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Micro-optimization: Always pass these paths directly to php without caching
    # to prevent hashing and cache lookup overhead
    # Note: virtual URLs might bypass this rule (e.g. /en/checkout)
    if (req.url ~ "^/(checkout|account|admin|api)(/.*)?$") {
        return (pass);
    }

    cookie.parse(req.http.cookie);

    # set cache-hash cookie value to header for hashing based on vary header
    # if header is provided directly the header will take precedence
    if (!req.http.sw-cache-hash) {
        set req.http.sw-cache-hash = cookie.get("sw-cache-hash");
    }

    # immediately pass when hash indicates that the content should not be cached
    # note that cache-hash = "not-cacheable" is used to indicate an application state in which the cache should be passed
    # we can not use cache-control headers in that case, as reverse proxies expect to always get the same cache-control headers based on the route
    # dynamically changing the cache-control header is not supported
    if (req.http.sw-cache-hash == "not-cacheable") {
        return (pass);
    }

    set req.http.currency = cookie.get("sw-currency");
    set req.http.states = cookie.get("sw-states");

    if (req.url == "/widgets/checkout/info" && (req.http.sw-cache-hash == "" || (cookie.isset("sw-states") && req.http.states !~ "cart-filled"))) {
        return (synth(204, ""));
    }

    #  Ignore query strings that are only necessary for the js on the client. Customize as needed.
    if (req.url ~ "(\?|&)(pk_campaign|piwik_campaign|pk_kwd|piwik_kwd|pk_keyword|pixelId|kwid|kw|adid|chl|dv|nk|pa|camid|adgid|cx|ie|cof|siteurl|utm_[a-z]+|_ga|gclid)=") {
        # see rfc3986#section-2.3 "Unreserved Characters" for regex
        set req.url = regsuball(req.url, "(pk_campaign|piwik_campaign|pk_kwd|piwik_kwd|pk_keyword|pixelId|kwid|kw|adid|chl|dv|nk|pa|camid|adgid|cx|ie|cof|siteurl|utm_[a-z]+|_ga|gclid)=[A-Za-z0-9\-\_\.\~%]+&?", "");
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
    if (req.http.sw-cache-hash != "") {
        hash_data("+context=" + req.http.sw-cache-hash);
    } elseif (req.http.currency != "") {
        hash_data("+currency=" + req.http.currency);
    }
}

sub vcl_hit {
  # Consider client states for response headers
  if (req.http.states) {
     if (req.http.states ~ "logged-in" && obj.http.sw-invalidation-states ~ "logged-in" ) {
        return (pass);
     }

     if (req.http.states ~ "cart-filled" && obj.http.sw-invalidation-states ~ "cart-filled" ) {
        return (pass);
     }
  }
}

sub vcl_backend_fetch {
    unset bereq.http.currency;
    unset bereq.http.states;
}

sub vcl_backend_response {
    # Serve stale content for three days after object expiration
    set beresp.grace = 3d;

    unset beresp.http.X-Powered-By;
    unset beresp.http.Server;

    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        unset beresp.http.Surrogate-Control;
        set beresp.do_esi = true;
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
