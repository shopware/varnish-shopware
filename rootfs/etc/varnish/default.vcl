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

    # Static assets don't need any cookie. Stripping them ensures a stable cache
    # key when assets are served from the same domain as the storefront, so the
    # hash does not vary based on sw-cache-hash or sw-currency.
    if (req.url ~ "^/(media|thumbnail|theme|bundles)/") {
        unset req.http.Cookie;
    }

    cookie.parse(req.http.cookie);

    # set cache-hash cookie value to header for hashing based on vary header
    # if header is provided directly the header will take precedence
    if (!req.http.sw-cache-hash) {
        set req.http.sw-cache-hash = cookie.get("sw-cache-hash");
    }

    set req.http.currency = cookie.get("sw-currency");
    set req.http.states = cookie.get("sw-states");

    if (req.url == "/widgets/checkout/info" && (req.http.sw-cache-hash == "" || (cookie.isset("sw-states") && req.http.states !~ "cart-filled"))) {
        return (synth(204, ""));
    }

    #  Ignore query strings that are only necessary for the js on the client. Customize as needed.
    if (req.url ~ "(\?|&)(pk_campaign|piwik_campaign|pk_kwd|piwik_kwd|pk_keyword|piwik_keyword|mtm_campaign|matomo_campaign|mtm_cid|matomo_cid|mtm_kwd|matomo_kwd|mtm_keyword|matomo_keyword|mtm_source|matomo_source|mtm_medium|matomo_medium|mtm_content|matomo_content|mtm_group|matomo_group|mtm_placement|matomo_placement|pixelId|kwid|kw|chl|dv|nk|pa|camid|adgid|yclid|utm_term|utm_source|utm_medium|utm_campaign|utm_content|cx|ie|cof|siteurl|_ga|adgroupid|campaignid|adid|utm_id|utm_source_platform|utm_creative_format|utm_marketing_tactic|_gl|gclsrc|gPromoCode|gQT|gclid|srsltid|dclid|gbraid|wbraid|gad_source|gad_campaignid|fbclid|fb_action_ids|fb_action_types|fb_source|mc_cid|mc_eid|_bta_tid|_bta_c|trk_contact|trk_msg|trk_module|trk_sid|gdfms|gdftrk|gdffi|_ke|_kx|redirect_log_mongo_id|redirect_mongo_id|sb_referer_host|mkwid|pcrid|ef_id|s_kwcid|msclkid|dm_i|epik|pp|twclid|hsa_cam|hsa_grp|hsa_mt|hsa_src|hsa_ad|hsa_acc|hsa_net|hsa_kw|hsa_tgt|hsa_ver|_branch_match_id|mkevt|mkcid|mkrid|campid|toolid|customid|igshid|si|ttclid|ScCid|rtid|irclickid|klar_source|klar_cpid|klar_adid)=") {
        # see rfc3986#section-2.3 "Unreserved Characters" for regex
        set req.url = regsuball(req.url, "(pk_campaign|piwik_campaign|pk_kwd|piwik_kwd|pk_keyword|piwik_keyword|mtm_campaign|matomo_campaign|mtm_cid|matomo_cid|mtm_kwd|matomo_kwd|mtm_keyword|matomo_keyword|mtm_source|matomo_source|mtm_medium|matomo_medium|mtm_content|matomo_content|mtm_group|matomo_group|mtm_placement|matomo_placement|pixelId|kwid|kw|chl|dv|nk|pa|camid|adgid|yclid|utm_term|utm_source|utm_medium|utm_campaign|utm_content|cx|ie|cof|siteurl|_ga|adgroupid|campaignid|adid|utm_id|utm_source_platform|utm_creative_format|utm_marketing_tactic|_gl|gclsrc|gPromoCode|gQT|gclid|srsltid|dclid|gbraid|wbraid|gad_source|gad_campaignid|fbclid|fb_action_ids|fb_action_types|fb_source|mc_cid|mc_eid|_bta_tid|_bta_c|trk_contact|trk_msg|trk_module|trk_sid|gdfms|gdftrk|gdffi|_ke|_kx|redirect_log_mongo_id|redirect_mongo_id|sb_referer_host|mkwid|pcrid|ef_id|s_kwcid|msclkid|dm_i|epik|pp|twclid|hsa_cam|hsa_grp|hsa_mt|hsa_src|hsa_ad|hsa_acc|hsa_net|hsa_kw|hsa_tgt|hsa_ver|_branch_match_id|mkevt|mkcid|mkrid|campid|toolid|customid|igshid|si|ttclid|ScCid|rtid|irclickid|klar_source|klar_cpid|klar_adid)=[A-Za-z0-9\-\_\.\~%]+&?", "");
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

    # This should happen before any early return via deliver, so that ESI can still be processed
    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        unset beresp.http.Surrogate-Control;
        set beresp.do_esi = true;
    }

    # Reducing hit-for-miss duration for dynamically uncacheable responses
    if (beresp.http.sw-dynamic-cache-bypass == "1") {
        # Mark as "Hit-For-Miss" for the next n seconds
        set beresp.ttl = 1s;
        set beresp.uncacheable = true;
        unset beresp.http.sw-dynamic-cache-bypass;
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
    ## we don't want the client to cache anything except assets and store-api responses
    if (resp.http.Cache-Control !~ "private" && req.url !~ "^/(theme|media|thumbnail|bundles|store-api)/") {
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
