# Shopware Varnish Docker image

The image bases on the official [Varnish image](https://hub.docker.com/_/varnish) and contains the Shopware default VCL.

## Additional environment variables

- `SHOPWARE_BACKEND_HOST` - The host of the Shopware backend. Default: `localhost`
- `SHOPWARE_BACKEND_PORT` - The port of the Shopware backend. Default: `8000`
- `SHOPWARE_SOFT_PURGE` - If set to `1`, the soft purge feature is enabled. Default: `0`

## Example usage

```bash
docker run \
    --rm \
    -it \
    # host ip where Shopware is
    -e SHOPWARE_BACKEND_HOST=host.docker.internal \
    -p 8080:80 \
    --name=varnish \
    varnish
```
