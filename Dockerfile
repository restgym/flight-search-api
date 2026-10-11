FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /api /infrastructure /results

# Install required packages including MongoDB
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install \
        openjdk-21-jdk \
        curl \
        wget \
        python3 \
        python3-pip \
        gnupg \
        ca-certificates && \
    pip3 install mitmproxy requests && \
    curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg && \
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && \
    apt-get -y install mongodb-org && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./apis/flight-search/ /api/

COPY ./infrastructure/jacoco/collect-coverage_0-8-12.sh /infrastructure/jacoco/collect-coverage.sh

COPY ./infrastructure/jacoco/collect-coverage-interval.sh /infrastructure/jacoco/collect-coverage-interval.sh

COPY ./infrastructure/jacoco/org.jacoco.agent-0.8.12-runtime.jar /infrastructure/jacoco/
COPY ./infrastructure/jacoco/org.jacoco.cli-0.8.12-nodeps.jar /infrastructure/jacoco/

COPY ./infrastructure/mitmproxy/ /infrastructure/mitmproxy/
EXPOSE 9090 12345 8080 27017

# Startup script: starts the API, the collection of code coverage and the proxy (see infrastructure/api/restgym-api.sh)
COPY ./infrastructure/api/ /infrastructure/api/
COPY ./apis/flight-search/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["bash", "/entrypoint.sh"]
