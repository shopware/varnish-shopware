#!/bin/sh
set -eu

# Run inside the image: sh tests/static-assets.sh /source/6.7/rootfs/etc/varnish/default.vcl
test_dir=$(mktemp -d)
test_file=$test_dir/static-assets.vtc
trap 'rm -rf "$test_dir"' EXIT
policy="script-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'"

{
    echo 'varnishtest "Asset CSP covers every file type and preserves application policies"'
    echo 'server s1 {'
    # The first asset is requested twice; the second request must be a cache hit.
    for status in 200 200 200 200 200 200 200 200 200 200 404; do
        echo 'rxreq'
        echo "txresp -status $status -hdr \"Cache-Control: public, max-age=3600\" -hdr \"Content-Security-Policy: default-src 'self'\" -body response"
    done
    echo '} -start'
    echo 'varnish v1 -vcl {'
    sed -e "s/__SHOPWARE_BACKEND_HOST__/\${s1_addr}/g" \
        -e "s/__SHOPWARE_BACKEND_PORT__/\${s1_port}/g" \
        -e 's/__SHOPWARE_ALLOWED_PURGER_IP__/"127.0.0.1"/g' "$1"
    echo '} -start'
    echo 'client c1 {'
    for path in /media/test.html /media/test.html /thumbnail/test.svg /theme/app.js /bundles/app/index.html /media/image.png /media/no-extension /media/test.html?download=1 /admin /application/rendered.html /media-other/test.html /media/missing.html; do
        expected_policy=$policy
        case "$path" in
            /admin|/application/*|/media-other/*) expected_policy="default-src 'self'" ;;
        esac
        status=200
        [ "$path" != /media/missing.html ] || status=404
        echo "txreq -url \"$path\""
        echo 'rxresp'
        echo "expect resp.status == $status"
        echo "expect resp.http.Content-Security-Policy == \"$expected_policy\""
    done
    echo '} -run'
    echo 'varnish v1 -expect MAIN.cache_hit == 1'
} > "$test_file"
varnishtest "$test_file"
