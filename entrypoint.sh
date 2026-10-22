#!/usr/bin/env bash
# Starts Flight Search in RESTgym: see /infrastructure/api/restgym-api.sh

source /infrastructure/api/restgym-api.sh

RESTGYM_PROXY_SCRIPTS=(/api/auth.py)

# MongoDB, empty at each start (as in the original repository, which provides no data)
mkdir -p /data/db
mongod --fork --logpath /var/log/mongodb.log --dbpath /data/db || restgym_fail "MongoDB did not start."
restgym_wait_for_port MongoDB 27017

# The administrator with which the proxy signs in (auth.py), registered before the tools start (so that no tool can
# register its email first; the email is one a tool would not choose, unlike, e.g., test@example.com). Without it, every
# request would get 401: the container stops, and RESTgym runs the run again
restgym_on_api_ready() {
    curl -sf -o /dev/null -X POST http://localhost:8080/api/v1/authentication/user/register \
        -H 'Content-Type: application/json' \
        -d '{"email": "restgym-proxy@restgym.com", "password": "Password123!", "firstName": "RESTgym", "lastName": "Admin",
             "phoneNumber": "12345678903", "userType": "ADMIN"}' \
        || restgym_fail "The registration of the administrator of the proxy failed."
    restgym_log "Administrator of the proxy registered."
}

# server.error.include-message: the errors that the API leaves to Spring (e.g., 500) have the message of the exception
# in their body, as the answers of its handler of exceptions do (RESTgym groups the 5XX into unique failures by message)
restgym_run_api 8080 \
    java -javaagent:/infrastructure/jacoco/org.jacoco.agent-0.8.12-runtime.jar=includes=*,output=tcpserver,port=12345,address=* \
        -Dfile.encoding=UTF-8 \
        -Dserver.port=8080 \
        -Dspring.data.mongodb.host=localhost \
        -Dspring.data.mongodb.port=27017 \
        -Dspring.data.mongodb.database=flightdatabase \
        -Dserver.error.include-message=always \
        -jar /api/flightsearchapi.jar
