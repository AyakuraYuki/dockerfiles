FROM browserless/chrome:latest
USER root
ENV LAND zh_CN.UTF-8
RUN localedef -c -f UTF-8 -i zh_CN zh_CN.utf8 \
    && export LAND=zh_CN.UTF-8 \
    && echo -e "export LAND=zh_CN.UTF-8" > /etc/locale.conf \
    && cd /tmp \
    && apt-get update \
    && apt-get install -fy tzdata \
    && ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo Asia/Shanghai > /etc/timezone
USER blessuser
