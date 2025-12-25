#!/bin/bash

docker-compose up -d --build
sleep 3
./scripts/mongo-init.sh
sleep 3
./scripts/redis-init.sh