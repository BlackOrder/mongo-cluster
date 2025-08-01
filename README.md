# Percona MongoDB Cluster

A production-ready, secure MongoDB cluster using **Percona Server for MongoDB** with automatic replica set configuration, dynamic keyfile generation, and comprehensive management features.

## 🚀 Quick Start

```bash
# Clone this repository
git clone <repository-url>
cd mongo-cluster

# Start the cluster (interactive setup)
make start

# Check cluster status
make status

# Test connections
make test-connection

# View cluster health
make test-replica
```

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Installation & Setup](#-installation--setup)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Web UI Management](#-web-ui-management)
- [Security](#-security)
- [Monitoring & Management](#-monitoring--management)
- [Troubleshooting](#-troubleshooting)
- [Advanced Operations](#-advanced-operations)
- [Commands Reference](#-commands-reference)

## ✨ Features

### Core Features
- **Percona Server for MongoDB 6.0**: Enhanced MongoDB with advanced security, auditing, and performance features
- **3-Node Replica Set**: Automatic high-availability configuration with 1 primary + 2 secondary nodes
- **Interactive Setup**: Guided credential and port configuration with password confirmation
- **Dynamic Security**: Auto-generated 700-byte keyfiles with proper cleanup
- **Production Ready**: Separate setup and production deployment modes with automatic transitions

### Security Features
- **Dynamic Keyfile Generation**: 700-byte random keyfiles created during setup
- **Secure Defaults**: Strong authentication and authorization out of the box
- **Isolated Networks**: Docker network isolation for cluster communication
- **Credential Management**: Environment-based credential handling with interactive setup
- **Clean Setup Process**: Setup containers automatically removed after initialization

### Management Features
- **One-Command Deployment**: Single `make start` command handles everything
- **Health Monitoring**: Built-in health checks and status commands
- **Easy Cleanup**: Simple environment reset and data volume management
- **Optional Web UI**: Enable/disable MongoDB management interfaces as needed
- **Flexible Port Configuration**: Customizable ports with localhost-only defaults
- **Automatic Orphan Cleanup**: No leftover containers or volumes

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Percona MongoDB Cluster                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │  mongodb1   │    │  mongodb2   │    │  mongodb3   │    │
│  │  (PRIMARY)  │◄──►│ (SECONDARY) │◄──►│ (SECONDARY) │    │
│  │   :27017    │    │   :27018    │    │   :27019    │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            Hostname Resolution (/etc/hosts)         │   │
│  │   mongodb1 → 127.0.0.1:27017 (Primary)            │   │
│  │   mongodb2 → 127.0.0.1:27018 (Secondary 1)        │   │
│  │   mongodb3 → 127.0.0.1:27019 (Secondary 2)        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Shared Security Keyfile                │   │
│  │            (Auto-Generated, 700-byte)              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Optional: Web UI                      │   │
│  │         (Mongo Express or Alternatives)            │   │
│  │                    :8081                           │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Deployment Phases

1. **Setup Phase**: Initialization containers create keyfile and configure replica set
2. **Production Phase**: Clean runtime with only MongoDB nodes and optional UI
3. **Auto-Cleanup**: Setup containers are automatically removed after successful initialization

## 📦 Prerequisites

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher  
- **Make**: GNU Make for command execution
- **Bash**: For interactive setup scripts
- **NetCat (nc)**: For connection testing (usually pre-installed)

### System Requirements
- **Memory**: Minimum 4GB RAM (8GB+ recommended for production)
- **Storage**: At least 10GB free space for data volumes
- **Network**: Ports 27017-27019 and 8081 available on localhost

## 🛠 Installation & Setup

### 1. Clone Repository
```bash
git clone <repository-url>
cd mongo-cluster
```

### 2. Start Cluster (First Time)
```bash
make start
```

The interactive setup will prompt for:
- **MongoDB Username** (default: `admin`)
- **MongoDB Password** (default: `devpassword123`)
- **Password Confirmation** (for safety)
- **Port Configuration** (defaults: 27017, 27018, 27019)
  - Primary MongoDB Port
  - Secondary 1 MongoDB Port  
  - Secondary 2 MongoDB Port
- **Hostname Configuration** (defaults: mongodb1, mongodb2, mongodb3)
  - Primary hostname
  - Secondary 1 hostname
  - Secondary 2 hostname

You can use different port formats:
- `27017` - Localhost only (secure default)

#### Example Interactive Setup
```bash
$ make start
🔧 Setting up MongoDB cluster for the first time...

📝 Please provide MongoDB credentials (or press Enter for defaults):

MongoDB Username [admin]: myuser
MongoDB Password [devpassword123]: 
Confirm Password: 

📌 Port Configuration (press Enter for defaults):
   Format: port (e.g., 27017)

MongoDB Primary Port [27017]: 
MongoDB Secondary 1 Port [27018]: 27028
MongoDB Secondary 2 Port [27019]: 

Creating .env file with your settings...
✅ Created .env file with your credentials

🚀 Starting cluster with initialization (first-time setup)...
⏳ Waiting for cluster initialization to complete...
🎯 Cluster initialization completed successfully!
🔄 Switching to production mode...
✅ Cluster is now running in production mode

🔗 Connection Information:
Primary: mongodb://myuser:********@localhost:27017/admin
Replica 1: mongodb://myuser:********@localhost:27028/admin
Replica 2: mongodb://myuser:********@localhost:27019/admin

Cluster Connection String:
mongodb://myuser:********@localhost:27017,localhost:27028,localhost:27019/admin?replicaSet=rs

🌐 Optional: Enable web UI with 'make ui-enable' for database management
```

### 3. Verify Installation
```bash
# Check all services are running
make status

# Test port connectivity
make test-connection

# Verify replica set health
make test-replica
```

## ⚙ Configuration

### Environment Variables

The system automatically creates a `.env` file during first run. You can modify these settings:

```bash
# MongoDB credentials
MONGODB_USERNAME=admin
MONGODB_PASSWORD=devpassword123

# Port mappings (localhost only by default)
FORWARD_MONGODB1_PORT=27017    # Primary node
FORWARD_MONGODB2_PORT=27018    # Secondary node 1  
FORWARD_MONGODB3_PORT=27019    # Secondary node 2

# Hostname configuration (for replica set member identification)
MONGODB1_HOST=mongodb1         # Primary hostname
MONGODB2_HOST=mongodb2         # Secondary 1 hostname
MONGODB3_HOST=mongodb3         # Secondary 2 hostname

# Web UI Configuration (added when ui-enable is used)
# FORWARD_MONGODB_EXPRESS_PORT=8081  # Web UI port

# Deployment mode (automatically managed)
DEPLOYMENT_MODE=production
```

### Custom Hostname Configuration

The hostname configuration allows you to use custom hostnames for replica set members, which is essential for proper client redirection and external access:

**1. During setup, you can specify custom hostnames:**
```bash
Primary hostname [mongodb1]: mongo1.mycompany.com
Secondary 1 hostname [mongodb2]: mongo2.mycompany.com  
Secondary 2 hostname [mongodb3]: mongo3.mycompany.com
```

**2. Add entries to your /etc/hosts file:**
```bash
# Add these entries to /etc/hosts for hostname resolution
127.0.0.1    mongo1.mycompany.com
127.0.0.1    mongo2.mycompany.com
127.0.0.1    mongo3.mycompany.com
```

**3. Or use the provided commands:**
```bash
echo '127.0.0.1    mongo1.mycompany.com' | sudo tee -a /etc/hosts
echo '127.0.0.1    mongo2.mycompany.com' | sudo tee -a /etc/hosts
echo '127.0.0.1    mongo3.mycompany.com' | sudo tee -a /etc/hosts
```

> **Why hostnames matter**: MongoDB replica sets use hostnames for member identification and client redirection. When you connect to a secondary node, MongoDB redirects write operations to the primary using these hostnames. Without proper hostname resolution, client redirection will fail.

### Custom Port Configuration

The ports are fully customizable through the `.env` file. You can:

**1. Use different port numbers:**
```bash
FORWARD_MONGODB1_PORT=27021
FORWARD_MONGODB2_PORT=27022  
FORWARD_MONGODB3_PORT=27023
FORWARD_MONGODB_EXPRESS_PORT=8082
```

**2. Configure non-standard setups:**
```bash
# High ports for unprivileged users
FORWARD_MONGODB1_PORT=37017
FORWARD_MONGODB2_PORT=37018
FORWARD_MONGODB3_PORT=37019
```

## 🎯 Usage

### Basic Operations

```bash
# Start cluster
make start

# Stop cluster  
make stop

# Restart cluster
make restart

# View logs
make logs

# Clean everything (removes data!)
make clean
```

### Connection Examples

#### Direct Connection (Primary)
```bash
# Using mongosh
mongosh "mongodb://admin:devpassword123@localhost:27017/admin"

# Using connection string
mongodb://admin:devpassword123@localhost:27017/admin
```

#### Replica Set Connection (Recommended)
```bash
# Full cluster connection (default hostnames)
mongodb://admin:devpassword123@mongodb1:27017,mongodb2:27018,mongodb3:27019/admin?replicaSet=rs

# Custom hostnames example
mongodb://admin:devpassword123@mongo1.mycompany.com:27017,mongo2.mycompany.com:27018,mongo3.mycompany.com:27019/admin?replicaSet=rs

#### Python Example
```python
from pymongo import MongoClient

# Replica set connection (recommended)
client = MongoClient(
    "mongodb://admin:devpassword123@localhost:27017,localhost:27018,localhost:27019/admin?replicaSet=rs"
)

# Test connection
db = client.admin
print(db.command("ping"))

# Use your database
mydb = client.mydatabase
collection = mydb.mycollection
```

#### Node.js Example
```javascript
const { MongoClient } = require('mongodb');

const uri = "mongodb://admin:devpassword123@localhost:27017,localhost:27018,localhost:27019/admin?replicaSet=rs";
const client = new MongoClient(uri);

async function run() {
  try {
    await client.connect();
    console.log("Connected to MongoDB cluster!");
    
    const db = client.db("mydatabase");
    const collection = db.collection("mycollection");
    
    // Your operations here
  } finally {
    await client.close();
  }
}

run().catch(console.dir);
```

## 🌐 Web UI Management

### Enable Mongo Express
```bash
make ui-enable
```

This will:
1. Prompt for web UI port configuration (default: 8081)
2. Create `docker-compose.override.yml` with Mongo Express configuration
3. Start the web UI container
4. Display access URL

#### Example UI Setup
```bash
$ make ui-enable
📌 Web UI Port Configuration:

Mongo Express Web UI Port [8081]: 8082

✅ Added web UI port configuration to .env
✅ Mongo Express enabled at http://localhost:8082
```

### Disable Web UI
```bash
make ui-disable
```

### Restart Web UI
```bash
make ui-restart
```

### Alternative Web UIs
See `WEB_UI_ALTERNATIVES.md` for other MongoDB management tools like:
- MongoDB Compass
- Studio 3T
- Robo 3T
- NoSQLBooster

## 🔒 Security

### Security Features
- **Keyfile Authentication**: 700-byte random keyfiles for inter-node communication
- **User Authentication**: MongoDB user authentication enabled by default
- **Network Isolation**: Docker network prevents external access to internal communication
- **Localhost Binding**: Default port bindings only allow localhost connections
- **Clean Setup**: No temporary files or setup containers left behind

### Security Best Practices
- **Change default credentials** before production use
- **Use strong passwords** (minimum 12 characters)
- **Enable TLS/SSL** in production environments
- **Implement proper firewall rules** for production deployments
- **Regular backups** are essential for data protection
- **Monitor access logs** for suspicious activity

## 📊 Monitoring & Management

### Container Health
```bash
# Check container status
make status

# View detailed logs
make logs

# Monitor specific service
docker compose logs -f mongodb1
```

### Database Health
```bash
# Test connectivity
make test-connection

# Check replica set status
make test-replica

# View cluster statistics
docker exec $(docker compose ps -q mongodb1) mongosh --eval "db.runCommand('serverStatus')" --username admin --password devpassword123
```

### Replica Set Behavior
- **Writes**: Always go to the PRIMARY node
- **Reads**: Can be directed to PRIMARY or SECONDARY nodes
- **Failover**: If PRIMARY fails, a SECONDARY automatically becomes PRIMARY
- **Sync**: SECONDARY nodes continuously sync from PRIMARY

## 🐛 Troubleshooting

### Common Issues

**1. Containers failing to start**
```bash
# Check logs
make logs

# Verify .env file exists
ls -la .env
```

**2. Connection refused**
```bash
# Verify ports are available
netstat -tulpn | grep :27017

# Check if containers are running
make status
```

**3. Replica set not forming**
```bash
# Wait for health checks to pass (up to 40 seconds)
make status

# Check if setup completed successfully
docker logs $(docker compose ps -q mongo-setup) 2>/dev/null || echo "Setup container not found (normal if setup completed)"
```

**4. "Could not find member to sync from" on PRIMARY**
- This is **normal behavior** - PRIMARY nodes don't sync from others
- Only worry if SECONDARY nodes show this message persistently

**5. Setup containers still running**
```bash
# This usually means setup failed or is still in progress
make logs

# If setup is stuck, you can force cleanup:
docker compose down --remove-orphans
rm -f docker-compose.override.yml
make start
```

**6. Hostname resolution issues**
```bash
# Check if /etc/hosts entries are correct
cat /etc/hosts | grep mongodb

# Test hostname resolution
ping mongodb1
ping mongodb2
ping mongodb3

# Add missing entries (example)
echo '127.0.0.1    mongodb1' | sudo tee -a /etc/hosts
echo '127.0.0.1    mongodb2' | sudo tee -a /etc/hosts
echo '127.0.0.1    mongodb3' | sudo tee -a /etc/hosts
```

**7. Client redirection failures**
- This happens when replica set uses hostnames that clients can't resolve
- Solution: Ensure hostnames in replica set config match /etc/hosts entries
- Or use localhost-based connection strings for direct access
```bash
# This usually means setup failed or is still in progress
make logs

# If setup is stuck, you can force cleanup:
docker compose down --remove-orphans
rm -f docker-compose.override.yml
make start
```

### Recovery Procedures

**Reset everything**:
```bash
make clean  # ⚠️ Removes all data
make start
```

**Force production mode**:
```bash
# If setup is stuck, force switch to production
sed -i 's/DEPLOYMENT_MODE=setup/DEPLOYMENT_MODE=production/' .env
rm -f docker-compose.override.yml
make start
```

**Clean orphaned volumes**:
```bash
docker volume prune -f
```

## 🔧 Advanced Operations

### Accessing the MongoDB Shell
```bash
# Connect to primary
docker exec -it $(docker compose ps -q mongodb1) mongosh --username admin --password devpassword123

# Connect to secondary (read-only)
docker exec -it $(docker compose ps -q mongodb2) mongosh --username admin --password devpassword123
```

### Backup and Restore
```bash
# Create backup
docker exec $(docker compose ps -q mongodb1) mongodump --username admin --password devpassword123 --out /tmp/backup

# Copy backup to host
docker cp $(docker compose ps -q mongodb1):/tmp/backup ./backup

# Restore backup
docker exec -i $(docker compose ps -q mongodb1) mongorestore --username admin --password devpassword123 /tmp/backup
```

### Custom MongoDB Configuration
For custom MongoDB settings, modify the `command` sections in `docker-compose.yml`:

```yaml
command: 
  - --bind_ip_all
  - --replSet
  - rs
  - --keyFile
  - /etc/mongo/mongodb-key
  - --wiredTigerCacheSizeGB
  - "1"  # Custom cache size
  - --logpath
  - /var/log/mongodb/mongod.log
```

### Scaling Considerations
This setup is designed for development and small production workloads. For larger deployments:
- Consider using MongoDB sharding
- Implement proper monitoring (Prometheus/Grafana)
- Use dedicated hardware for each replica
- Implement proper backup strategies
- Consider MongoDB Atlas for managed solutions

## 📚 Commands Reference

### Main Commands
| Command | Description |
|---------|-------------|
| `make start` | Start cluster (interactive setup on first run) |
| `make stop` | Stop all cluster services |
| `make restart` | Restart cluster |
| `make status` | Show container status |
| `make logs` | View service logs |
| `make clean` | Remove all data and reset environment |

### Testing Commands
| Command | Description |
|---------|-------------|
| `make test-connection` | Test port connectivity |
| `make test-replica` | Check replica set status |

### Web UI Commands
| Command | Description |
|---------|-------------|
| `make ui-enable` | Enable Mongo Express web UI |
| `make ui-disable` | Disable web UI |
| `make ui-restart` | Restart web UI |

### Useful Docker Commands
```bash
# View all containers (including stopped)
docker compose ps -a

# Remove orphaned containers and volumes
docker compose down --remove-orphans -v

# View detailed container information
docker inspect $(docker compose ps -q mongodb1)

# Execute commands in containers
docker exec -it $(docker compose ps -q mongodb1) bash
```

## 📄 File Structure

```
mongo-cluster/
├── README.md                    # This documentation
├── WEB_UI_ALTERNATIVES.md      # Alternative UI options
├── Makefile                    # Main command interface
├── docker-compose.yml          # Production cluster definition
├── docker-compose.setup.yml    # Setup phase containers
├── .env                        # Environment configuration (auto-generated)
├── docker-compose.override.yml # Optional UI or setup override (auto-managed)
└── LICENSE                     # License information
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `make clean && make start`
5. Submit a pull request

## 📚 Additional Resources

- [Percona Server for MongoDB Documentation](https://docs.percona.com/percona-server-for-mongodb/)
- [MongoDB Replica Set Documentation](https://docs.mongodb.com/manual/replication/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [MongoDB Connection String Reference](https://docs.mongodb.com/manual/reference/connection-string/)

## 📄 License

This project is licensed under the terms specified in the LICENSE file.

---

**Happy coding with your secure, production-ready MongoDB cluster! 🚀**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MongoDB 1     │    │   MongoDB 2     │    │   MongoDB 3     │
│   (PRIMARY)     │◄──►│  (SECONDARY)    │◄──►│  (SECONDARY)    │
│   Port: 27017   │    │   Port: 27018   │    │   Port: 27019   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  Mongo Express  │
                    │   Port: 8081    │
                    └─────────────────┘
```
