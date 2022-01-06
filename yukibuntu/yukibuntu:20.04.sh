#!/usr/bin/env bash

# The following commands run in the host machine.
docker pull ubuntu:20.04
docker run -t -i --name yukibuntu ubuntu:20.04

# ----------------------------------------------------------------------------------------------------
# After entering the container, run the following command.
apt-get update \
    && apt-get upgrade \
    && apt-get install -fy git vim zsh \
    && chsh -s /bin/zsh \
    && exit
# ----------------------------------------------------------------------------------------------------

# After returning the host, run the following command.
docker commit -m "package" -a "AyakuraYuki" yukibuntu ayakurayuki/yukibuntu:20.04
docker push ayakurayuki/yukibuntu:20.04
