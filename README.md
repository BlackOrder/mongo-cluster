# MongoDB CLuster Service

Custom docker image with automatic clustering. Beware!!: The service can only be initilize once. If you remove the containers, you have to delete all volumes associated with the service.

### Table of Contents
1. **[Setup MongoDB CLuster](#setup-mongodb-cluster)**<br>
    + **[Docker](#docker)**<br>
        * **[Prepare variables](#prepare-variables)**<br>
        * **[Create cluster key](#create-cluster-key)**<br>
            1. **[One line](#one-line)**<br>
            2. **[Manually](#manually)**<br>
        * **[Start MongoDB cluster service](#start-mongodb-cluster-service)**<br>

## Setup MongoDB CLuster
### Docker
#### Prepare variables:
```
cp .env.example .env
```
Edit the `.env` file. change the default username and password.

#### Create cluster key:
Mongo nodes need to share the same key to be able to authenticate each-other


##### One line:
```
echo "MONGODB_CLUSTER_KEY="$(openssl rand -base64 756 | sed -z 's/\n/\\n/g') >> .env
```
if the above failes to create the env variable in `.env` file, you have to do it in multiple steps.


##### Manually
1. Create key file:
```
openssl rand -base64 756 > mongo_cluster_key
```

2. Edit Key:
```
vim ./mongo_cluster_key
```
replace all new-line with `\n`

3. Step 3:
Create a variable in `.env` file and use the string from `Step 2` as it's value
```
MONGODB_CLUSTER_KEY=####-Single line encrypted key-####
```

#### Start MongoDB cluster service:
```
docker compose up -d
```
