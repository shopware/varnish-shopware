# Shopware Varnish Docker image

The image bases on the official [Varnish image](https://hub.docker.com/_/varnish) and contains the Shopware default VCL.
The containing VCL is for the usage with xkeys.

<details>
  <summary>Config for Shopware 6.6</summary>

```yaml
# config/packages/varnish.yaml

shopware:
    http_cache:
        reverse_proxy:
            enabled: true
            use_varnish_xkey: true
            hosts:
                # address to this varnish container or all varnish containers
                - localhost
```

</details>

<details>
  <summary>Config for Shopware 6.4 or 6.5</summary>

```yaml
# config/packages/varnish.yaml

storefront:
    reverse_proxy:
        enabled: true
        use_varnish_xkey: true
        hosts:
            # address to this varnish container or all varnish containers
            - localhost
```

</details>


## Example usage

```bash
docker run \
    --rm \
    -it \
    # host ip where Shopware is
    -e SHOPWARE_BACKEND_HOST=host.docker.internal \
    -p 8080:80 \
    ghcr.io/shopware/varnish:latest
```

## Additional environment variables

- `SHOPWARE_BACKEND_HOST` - The host of the Shopware backend. Default: `localhost`
- `SHOPWARE_BACKEND_PORT` - The port of the Shopware backend. Default: `8000`
- `SHOPWARE_SOFT_PURGE` - If set to `1`, the soft purge feature is enabled. Default: `0`
- `SHOPWARE_ALLOWED_PURGER_IP` - The IP address of the allowed purger. Default: `"127.0.0.1"`

The `SHOPWARE_ALLOWED_PURGER_IP` can be a single IP like `"172.17.0.1"` or a subnet like `"172.17.0.0"/24`. Take care that the ip address inside the environment variable needs to be double quoted.

## Further information

As this image bases on the Official Varnish image, you can use all options available there. For more information, please visit the [official Varnish image documentation](https://hub.docker.com/_/varnish).
