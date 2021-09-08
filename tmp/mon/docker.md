# Run PostgreSQL Inside Docker





```
docker run -p5432:5432 -d \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_INITDB_ARGS="-k" \
    -v /pg/docker/data:/var/lib/postgresql/data \
    --name pg1 \
    postgres

docker run -p5433:5432 -d \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_INITDB_ARGS="-k" \
    -v /pg/docker/data:/var/lib/postgresql/data \
    --name pg2 \
    postgres    

docker exec -it pg1 psql -U postgres
docker exec -it pg2 psql -U postgres

```

