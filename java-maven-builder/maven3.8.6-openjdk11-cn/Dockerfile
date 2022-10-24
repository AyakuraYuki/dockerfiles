FROM ayakurayuki/yukibuntu:20.04-slim
COPY kit/maven /opt/maven
COPY kit/jdk /opt/jdk
COPY config/sources.list /opt/sources.list
COPY config/maven-settings.xml /opt/maven-settings.xml
COPY ulimit/limits.conf /etc/security/limits.conf
COPY ulimit/sysctl.conf /etc/sysctl.conf
USER root
ENV LANG en_US.utf8
ENV MAVEN_HOME /opt/maven
ENV JAVA_HOME /opt/jdk
ENV JAVA_VERSION=11.0.16
ENV PATH="/opt/maven/bin:/opt/jdk/bin:$PATH"
RUN mkdir -p /opt/apache-maven-repository \
    && cp /opt/sources.list /etc/apt/sources.list \
    && cp /opt/maven-settings.xml /opt/maven/conf/settings.xml \
    && cp /opt/maven-settings.xml /opt/apache-maven-repository/settings.xml
