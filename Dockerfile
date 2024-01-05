# Google Cloud Pub/Sub Documentation
# https://cloud.google.com/pubsub/docs/

FROM google/cloud-sdk:458.0.1-alpine
LABEL maintainer="Cesar Perez <cesar@bigtruedata.com>" \
      version="0.1" \
      description="Google Cloud Pub/Sub Emulator"

ENV PROJECT_ID=project-id \
    TOPICS="topic-1 topic-2 topic-3 topic-4 topic-5 topic-6 topic-7" \
    SUB_NAMES=TOPIC-sub \
    ACK_DEADLINE=10

COPY rootfs /

## install openjdk, copied from https://github.com/docker-library/openjdk/blob/master/8-jre/alpine/Dockerfile

# Default to UTF-8 file.encoding
ENV LANG=C.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk \
    PATH=$PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin

# add a simple script that can auto-detect the appropriate JAVA_HOME value
# based on whether the JDK or only the JRE is installed
RUN { \
		echo '#!/bin/sh'; \
		echo 'set -e'; \
		echo; \
		echo 'dirname "$(dirname "$(readlink -f "$(which javac || which java)")")"'; \
	} > /usr/local/bin/docker-java-home \
	&& chmod +x /usr/local/bin/docker-java-home \
    && set -x \
	&& apk upgrade \
	&& apk add --no-cache openjdk8-jre \
	&& [ "$JAVA_HOME" = "$(docker-java-home)" ] \
## finish installing openjdk
    && \
    gcloud components install beta -q && \
    gcloud components install pubsub-emulator -q && \
    chmod +x /entrypoint.sh /usr/local/bin/* && \
    apk add --no-cache jq coreutils dpkg && \
    # install gosu
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    curl -fsSL "https://github.com/tianon/gosu/releases/download/1.16/gosu-$dpkgArch" -o /usr/local/bin/gosu && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true && \
    # complete gosu
    gosu cloudsdk gcloud config set core/disable_usage_reporting true && \
    gosu cloudsdk gcloud config set component_manager/disable_update_check true && \
    gosu cloudsdk gcloud config set metrics/environment github_docker_image && \
    mkdir /data && \
    chmod 777 /data && \
    # clean up
    # delete gosu as it's not used elsewhere
    rm -rf /usr/local/bin/gosu && \
    apk del dpkg && \
    rm -rf /apk /tmp/* /var/cache/apk/*

USER cloudsdk

EXPOSE 8538

ENTRYPOINT ["/entrypoint.sh"]
CMD []
