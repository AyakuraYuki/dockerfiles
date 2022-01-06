# java-maven-builder

> A basic docker image for building maven project.

## About this image

* ubuntu 20.04
* `java` and `mvn`
* as root user
* image tag, which ends with `-cn`, its apt repository and maven mirror has been changed to Aliyun.

## About `latest`

Currently the `latest` image is same with maven3.8.4-openjdk11-cn, apt repository and maven mirror has been changed to Aliyun.

## How to build

simply running `build.sh` to build image, but for those who use MacBook with Apple Silicon, use the following command to build image for amd64:

```shell
docker buildx build --platform=linux/amd64 -t "<tag_name>" .
```

## How to use this image

Here is a sample:

```Dockerfile
# latest image uses openjdk 11.0.13.1+8 and maven 3.8.4
FROM ayakurayuki/java-maven-builder:latest as build
USER root
RUN mkdir -p /opt/code
WORKDIR /opt/code
# copy all the project files into /opt/code in image, the pom.xml file should be places to /opt/code/pom.xml
COPY . ./
# any build command you want can be write here
RUN mvn compile install package

# build runnable image
FROM openjdk:11.0.9
RUN mkdir -p /data/package
COPY --from=build /opt/code/module/target/product-fat-1.0.jar /data/package/product.jar
```
