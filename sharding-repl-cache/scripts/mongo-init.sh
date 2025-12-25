#!/bin/bash
set -e

# 1. Инициализируем конфиг сервер
docker compose exec -T configSrv-1 mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv-1:27017" },
      { _id : 1, host : "configSrv-2:27027" },
      { _id : 2, host : "configSrv-3:27037" }
    ]
  }
);
EOF

# 2. Инициализируем шарды
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "shard1-1:27018" },
        { _id : 1, host : "shard1-2:27028" },
        { _id : 2, host : "shard1-3:27038" }
      ]
    }
);
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet <<EOF
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "shard2-1:27019" },
        { _id : 1, host : "shard2-2:27029" },
        { _id : 2, host : "shard2-3:27039" }
      ]
    }
);
EOF

# Даем время MongoDB выбрать Primary (важно для добавления шардов)
echo "Waiting for config server to elect primary..."
until docker compose exec -T configSrv-1 mongosh --port 27017 --quiet --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY')" | grep -q "PRIMARY"; do
  echo "Config server: waiting for primary..."
  sleep 2
done
echo "Config server primary elected!"

echo "Waiting for shard1 to elect primary..."
until docker compose exec -T shard1-1 mongosh --port 27018 --quiet --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY')" | grep -q "PRIMARY"; do
  echo "Shard1: waiting for primary..."
  sleep 2
done
echo "Shard1 primary elected!"

echo "Waiting for shard2 to elect primary..."
until docker compose exec -T shard2-1 mongosh --port 27019 --quiet --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY')" | grep -q "PRIMARY"; do
  echo "Shard2: waiting for primary..."
  sleep 2
done
echo "Shard2 primary elected!"

echo "Waiting for mongos router to be ready..."
until docker compose exec -T mongos_router1 mongosh --port 27020 --quiet --eval "db.adminCommand('ping')" | grep -q "ok"; do
  echo "Mongos: waiting to be ready..."
  sleep 2
done
echo "Mongos router is ready!"

# 3. Инициализация роутера
docker compose exec -T mongos_router1 mongosh --port 27020 --quiet <<EOF
sh.addShard( "shard1/shard1-1:27018,shard1-2:27028,shard1-3:27038");
sh.addShard( "shard2/shard2-1:27019,shard2-2:27029,shard2-3:27039");

sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } )

use somedb

for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})

db.helloDoc.countDocuments()
EOF