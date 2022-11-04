# Repository: ayakurayuki/openjdk
# Maintainer: Ayakura Yuki
#
# How to build this image:
#   1. go into the path of Dockerfile, e.g. /path/to/project/openjdk-cn
#   2. execute the following cmds:
#     JAVA_VERSION=<jdk-version-you-want>
#     docker buildx build --platform linux/amd64,linux/arm64 --build-arg JAVA_VERSION=${JAVA_VERSION} -t ayakurayuki/openjdk:${JAVA_VERSION} . --push
#
# How to make an alias with image:
#   use the following cmd:
#     docker tag ayakurayuki/openjdk:${JAVA_VERSION} ayakurayuki/openjdk:<another-version>
#
# FAQ
#   1. ERROR: multiple platforms feature is currently not supported for docker driver.
#     > Please switch to a different driver (eg. "docker buildx create --use")
#
ARG JAVA_VERSION
FROM openjdk:${JAVA_VERSION}
USER root
COPY config/sources.list /etc/apt/sources.list
RUN apt update && apt upgrade -fy && apt install -fy locales
RUN sed -i 's/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen && locale-gen
RUN echo "\
export LC_ALL=zh_CN.UTF-8\n\
export LANG=zh_CN.UTF-8\n\
export LANGUAGE=zh_CN.UTF-8\n\
" >> ~/.bashrc
RUN echo "\
export LC_ALL=zh_CN.UTF-8\n\
export LANG=zh_CN.UTF-8\n\
export LANGUAGE=zh_CN.UTF-8\n\
" >> ~/.zshrc
RUN apt install -fy zsh wget curl vim telnet
RUN chsh -s /bin/zsh
