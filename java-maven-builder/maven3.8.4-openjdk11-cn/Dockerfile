FROM ayakurayuki/yukibuntu:20.04-slim
# Args
ARG OUTSIDE_MAVEN=apache-maven-3.8.4
ARG OUTSIDE_JDK=jdk-11.0.13.8
# Copy files into image
COPY kit/${OUTSIDE_MAVEN} /opt/apache-maven
COPY kit/${OUTSIDE_JDK} /opt/jdk
COPY config/sources.list /opt/sources.list
COPY config/maven-settings.xml /opt/settings.xml
COPY ulimit/limits.conf /etc/security/limits.conf
COPY ulimit/sysctl.conf /etc/sysctl.conf
# Prepare image environment
USER root
RUN mkdir -p /opt/apache-maven-repository \
    && cp /opt/sources.list /etc/apt/sources.list \
    && cp /opt/settings.xml /opt/apache-maven/conf/settings.xml \
    && echo 'export LANG=en_US.utf8' >> ~/.bashrc \
    && echo 'export JAVA_HOME=/opt/jdk' >> ~/.bashrc \
    && echo 'export JAVA_VERSION=11.0.13' >> ~/.bashrc \
    && echo 'export MAVEN_HOME=/opt/apache-maven' >> ~/.bashrc \
    && echo 'export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"' >> ~/.bashrc \
    && echo 'export LANG=en_US.utf8' >> ~/.bash_profile \
    && echo 'export JAVA_HOME=/opt/jdk' >> ~/.bash_profile \
    && echo 'export JAVA_VERSION=11.0.13' >> ~/.bash_profile \
    && echo 'export MAVEN_HOME=/opt/apache-maven' >> ~/.bash_profile \
    && echo 'export PATH="${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"' >> ~/.bash_profile
# Prepare environment variables
ENV LANG en_US.utf8
ENV MAVEN_HOME /opt/apache-maven
ENV JAVA_HOME /opt/jdk
ENV JAVA_VERSION=11.0.13
ENV PATH "${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}"
