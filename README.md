# FlightSearchAPI

Flight search API con autenticazione JWT, gestione aeroporti/voli, MongoDB.

- Java 21, Spring Boot 3.4.1
- Repository: https://github.com/Rapter1990/flightsearchapi


## Docker

```bash
# Build
docker build -t flightsearchapi:restgym -f apis/flightsearchapi/Dockerfile .

# MongoDB
docker network create restgym-network
docker run -d --name mongodb --network restgym-network -e MONGO_INITDB_DATABASE=flightdatabase mongo:latest

# Run API
docker run -d --name flightsearchapi --network restgym-network \
  -p 9090:9090 -e API=flightsearchapi -e TOOL=manual -e RUN=1 \
  -v $(pwd)/results:/results flightsearchapi:restgym
```

Porte:
- 9090: MITM proxy (usare questa)
- 8080: API interna
- 12345: JaCoCo

## Test rapido

```bash
# Health check
curl http://localhost:9090/actuator/health

# Register
curl -X POST http://localhost:9090/api/v1/authentication/user/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!","firstName":"Admin","lastName":"User","phoneNumber":"12345678901","userType":"ADMIN"}'

# Login (salva token)
curl -X POST http://localhost:9090/api/v1/authentication/user/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123!"}'

# API call con token
curl http://localhost:9090/api/v1/airports -H "Authorization: Bearer TOKEN"
```

## Risultati

```
results/flightsearchapi/{TOOL}/{RUN}/
├── interactions.db    # SQLite HTTP logs
└── code-coverage/     # JaCoCo .exec + .csv
```
