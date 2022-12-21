#!/bin/bash

echo -e $MONGODB_CLUSTER_KEY > /data/db/mongodb_key
chmod 400 /data/db/mongodb_key
sleep 3

if [ ! -z "$MONGODB_CLUSTER_HOSTS" ]; then
    index=0
    arrMONGODB_CLUSTER_HOSTS=(${MONGODB_CLUSTER_HOSTS//,/ })
    hostsCount=1000
    for i in "${arrMONGODB_CLUSTER_HOSTS[@]}"; do
        if [ ! -z "$MONGODB_CLUSTER_HOSTS_CONFIGS" ]; then
            MONGODB_CLUSTER_HOSTS_CONFIGS="${MONGODB_CLUSTER_HOSTS_CONFIGS},"
        else
            MONGODB_CLUSTER_HOSTS_CONFIGS=""
        fi
        hostname=$(echo -e "$i" | xargs)
        MONGODB_CLUSTER_HOSTS_CONFIGS="${MONGODB_CLUSTER_HOSTS_CONFIGS}{ _id: ${index}, host: \"${hostname}\", priority: ${hostsCount}}"
        let "index+=1"
        let "hostsCount-=1"
    done
    mongosh -u "$1" -p "$2" --eval "rs.initiate({_id: '"'rs'"',version: 1,members: [$MONGODB_CLUSTER_HOSTS_CONFIGS]})"
fi
mongosh -u "$1" -p "$2" --eval "db.runCommand({ setClusterParameter: { changeStreamOptions: { preAndPostImages: { expireAfterSeconds: 100}}}})"
rm -- "$0"
