FROM ubuntu:22.04

ENV API=flightsearchapi
ENV TOOL=${TOOL:-manual}
ENV RUN=${RUN:-1}

RUN mkdir /api && \
    mkdir /infrastructure && \
    mkdir /results

RUN apt update && \
    apt -y upgrade && \
    apt -y install openjdk-21-jdk mitmproxy && \
    apt -y autoremove

COPY apis/flightsearchapi/flightsearchapi.jar /api/flightsearchapi.jar
RUN mkdir -p /api/classes && \
    cd /api/classes && \
    jar xf /api/flightsearchapi.jar && \
    find . -name "*.jar" -type f -delete

# Copy OpenAPI specifications for test generation
COPY apis/flightsearchapi/specifications/ /api/specifications/

COPY apis/infrastructure/ /infrastructure/

CMD mkdir -p /results/$API/$TOOL/$RUN/code-coverage && \
    cp -r /api/specifications /results/$API/$TOOL/$RUN/ && \
    sh /infrastructure/jacoco/collect-coverage-interval.sh & \
    mitmdump -p 9090 --mode reverse:http://localhost:8080/ -s /infrastructure/mitmproxy/store-interactions.py & \
    java -javaagent:/infrastructure/jacoco/org.jacoco.agent-0.8.7-runtime.jar=includes=*,output=tcpserver,port=12345,address=* \
        -Dfile.encoding=UTF-8 \
        -Dserver.port=8080 \
        -Dspring.data.mongodb.host=mongodb \
        -Dspring.data.mongodb.port=27017 \
        -Dspring.data.mongodb.database=flightdatabase \
        -jar /api/flightsearchapi.jar
