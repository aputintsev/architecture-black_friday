#!/bin/bash

docker compose exec -T redis_1 redis-cli --cluster create 173.18.0.19:6379 173.18.0.20:6379 173.18.0.21:6379 173.18.0.22:6379 173.18.0.23:6379 173.18.0.24:6379 --cluster-replicas 1 --cluster-yes