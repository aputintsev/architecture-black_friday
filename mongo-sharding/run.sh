#!/bin/bash

docker-compose up -d --build
sleep 3
./scripts/mongo-init.sh