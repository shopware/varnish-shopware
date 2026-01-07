# Shopware Varnish Docker image

The image bases on the official [Varnish image](https://hub.docker.com/_/varnish) and contains the Shopware default VCL.
The containing VCL is for the usage with xkeys.

<details>
  <summary>Config for Shopware 6.6 to 6.7</summary>

```yaml
# config/packages/varnish.yaml

shopware:
    # Cache tagging must be disabled with xkey config
    cache:
        tagging:
            each_config: false
            each_snippet: false
            each_theme_config: false

    http_cache:
        reverse_proxy:
            enabled: true
            use_varnish_xkey: true
            hosts:
                # address to this varnish container or all varnish containers
                - localhost
                # - varnish
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


## Environment variables

- `SHOPWARE_BACKEND_HOST` - The host of the Shopware backend. Default: `localhost`
- `SHOPWARE_BACKEND_PORT` - The port of the Shopware backend. Default: `8000`
- `SHOPWARE_SOFT_PURGE` - If set to `1`, the soft purge feature is enabled. Default: `0`
- `SHOPWARE_ALLOWED_PURGER_IP` - The IP address or Docker service name of the allowed purger. Default: `"127.0.0.1"`
- `VARNISH_SIZE` - The size of the Varnish cache. Default: `128m` (belongs to Varnish, not this image)

The `SHOPWARE_ALLOWED_PURGER_IP` can be a single IP like `"172.17.0.1"`, a subnet like `"172.17.0.0"/24` or any hostname like `shopware` inside the docker network. Take care that the ip address inside the environment variable needs to be double quoted.



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


## Compose example
```yaml
services:
   php:
     image: FROM shopware/docker-base:8.3-nginx
     networks:
        app:
     
   varnish:
       container_name: sw_varnish
       image: ghcr.io/shopware/varnish:latest
       restart: unless-stopped
       environment:
           SHOPWARE_BACKEND_HOST: php
           SHOPWARE_BACKEND_PORT: 8000
           SHOPWARE_ALLOWED_PURGER_IP: "\"php\""
           VARNISH_SIZE: 4G
       ports:
           - 8000:80
       depends_on:
           - php
       networks:
           app:
           proxy:
```

## Versioning

There are tags for all supported Shopware versions available, e.g. `6.7`, or unreleased versions like `6.8`.
A list of available tags can be viewed at <https://ghcr.io/shopware/varnish>.

### Branching

The `main` branch always contains the latest version of Shopware.
When there is a breaking change in the config a new branch is created for the upcoming Shopware version, e.g. `6.8`. 
Once the Shopware version is released, the branch is merged back into `main`, and the older version is maintained via a separate branch, e.g. `6.7`.

## Further information

As this image bases on the Official Varnish image, you can use all options available there. For more information, please visit the [official Varnish image documentation](https://hub.docker.com/_/varnish).
