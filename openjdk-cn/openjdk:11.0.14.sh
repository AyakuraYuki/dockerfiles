#!/usr/bin/env bash

docker pull openjdk:11.0.14
docker run -t -d --name openjdk openjdk:11.0.14
docker exec -it openjdk /bin/sh

# ----------------------------------------------------------------------------------------------------
apt-get update \
    && apt-get upgrade -fy \
    && apt-get install -fy vim locales \
    && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc \
    && echo "export LANG=en_US.UTF-8" >> ~/.bashrc \
    && echo "export LANGUAGE=en_US.UTF-8" >> ~/.bashrc \
    && exit
# ----------------------------------------------------------------------------------------------------

docker commit -m "package" -a "AyakuraYuki" openjdk ayakurayuki/openjdk:11.0.14-cn
docker push ayakurayuki/openjdk:11.0.14-cn
