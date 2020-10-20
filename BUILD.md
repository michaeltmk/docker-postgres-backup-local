# postgres-backup-local build instructions

To build and push all images to it's own repository.

## Prepare environment

* Configure you system to use [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/).
* Prepare crosscompile environment (see below).

### Prepare crosscompile environment

In order to work in Arch Linux the following initialization commands will be required:

```sh
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx rm multibuilder
docker buildx create --name multibuilder
docker buildx use multibuilder
#docker buildx create --name multibuilder --platform linux/amd64,linux/arm64,linux/arm/v7 --driver docker-container --use
docker buildx inspect --bootstrap
```

## Generate the images

### Generate build configuration

In order to modify the image name or any other configurable parameter run the `generate.sh` script.

```sh
IMAGE_NAME="michaeltse/docker-postgres-backup-local-s3" ./generate.sh config.hcl
```

### Build the images

In order to only build the images locally run the following command:

```sh
docker buildx bake --pull -f config.hcl
```

In order to publish directly to the repository run this command instead:

```sh
docker buildx bake --push --set common.output=type=registry -f config.hcl
```
