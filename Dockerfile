FROM ubuntu:22.04

ENV API=flight-search
ENV TOOL=${TOOL:-manual}
ENV RUN=${RUN:-1}
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
    pip3 install mitmproxy && \
    curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-6.0.gpg && \
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && \
    apt-get -y install mongodb-org && \
    apt-get -y autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 1. Copia dei file dell'API
COPY ./apis/flight-search/ /api/

# 2. Copia selettiva di infrastructure (Solo file necessari per Java 21 / JaCoCo 0.8.12)

# Copia lo script di collection specifico per la 0.8.12 rinominandolo come richiesto
COPY ./infrastructure/jacoco/collect-coverage_0-8-12.sh /infrastructure/jacoco/collect-coverage.sh

# Copia lo script che gestisce l'intervallo (usato nell'entrypoint)
COPY ./infrastructure/jacoco/collect-coverage-interval.sh /infrastructure/jacoco/collect-coverage-interval.sh

# Copia i JAR della versione 0.8.12 (Agente e CLI)
COPY ./infrastructure/jacoco/org.jacoco.agent-0.8.12-runtime.jar /infrastructure/jacoco/
COPY ./infrastructure/jacoco/org.jacoco.cli-0.8.12-nodeps.jar /infrastructure/jacoco/

# Copia lo script mitmproxy
COPY ./infrastructure/mitmproxy/ /infrastructure/mitmproxy/
EXPOSE 9090 12345 8080 27017

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
mkdir -p /results/$API/$TOOL/$RUN/code-coverage\n\
mkdir -p /results/$API/$TOOL/$RUN/logs\n\
mkdir -p /data/db\n\
\n\
echo "Starting MongoDB..."\n\
mongod --fork --logpath /var/log/mongodb.log --dbpath /data/db\n\
echo "Waiting for MongoDB to start..."\n\
sleep 10\n\
\n\
echo "Initializing MongoDB database..."\n\
if [ -f /api/database/init-mongo.js ]; then\n\
  mongosh flightdatabase /api/database/init-mongo.js || echo "MongoDB initialization completed with warnings"\n\
fi\n\
\n\
echo "Starting JaCoCo coverage collector..."\n\
sh /infrastructure/jacoco/collect-coverage-interval.sh &\n\
JACOCO_PID=$!\n\
\n\
echo "Starting Flight Search API in background..."\n\
java -javaagent:/infrastructure/jacoco/org.jacoco.agent-0.8.12-runtime.jar=includes=*,output=tcpserver,port=12345,address=* \\\n\
    -Dfile.encoding=UTF-8 \\\n\
    -Dserver.port=8080 \\\n\
    -Dspring.data.mongodb.host=localhost \\\n\
    -Dspring.data.mongodb.port=27017 \\\n\
    -Dspring.data.mongodb.database=flightdatabase \\\n\
    -jar /api/flightsearchapi.jar > /results/$API/$TOOL/$RUN/logs/api-stdout.log 2>&1 &\n\
API_PID=$!\n\
\n\
echo "Waiting for API to start..."\n\
for i in {1..60}; do\n\
  if curl -s http://localhost:8080 > /dev/null 2>&1; then\n\
    echo "API is ready!"\n\
    break\n\
  fi\n\
  if [ $i -eq 60 ]; then\n\
    echo "API failed to start in time"\n\
    exit 1\n\
  fi\n\
  sleep 1\n\
done\n\
\n\
echo "Starting mitmproxy..."\n\
mitmdump -p 9090 --mode reverse:http://localhost:8080/ -s /infrastructure/mitmproxy/store-interactions.py > /results/$API/$TOOL/$RUN/logs/mitmproxy.log 2>&1 &\n\
MITM_PID=$!\n\
\n\
echo "Waiting for mitmproxy to start..."\n\
sleep 10\n\
\n\
echo "All services started. Waiting for API process..."\n\
wait $API_PID\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]