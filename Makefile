.PHONY: help start stop restart logs clean test-connection status ui-enable ui-disable ui-restart

# Helper function to get container name dynamically
define get_container
$(shell docker compose ps -a -q $(1) 2>/dev/null)
endef

# Helper function to display connection information
define show_connection_info
	echo "🔗 Connection Information"; \
	echo "─────────────────────────"; \
	MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
	MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
	MONGODB1_HOST=$$(grep '^MONGODB1_HOST=' .env | cut -d'=' -f2); \
	MONGODB2_HOST=$$(grep '^MONGODB2_HOST=' .env | cut -d'=' -f2); \
	MONGODB3_HOST=$$(grep '^MONGODB3_HOST=' .env | cut -d'=' -f2); \
	MONGODB1_PORT=$$(grep '^FORWARD_MONGODB1_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	MONGODB2_PORT=$$(grep '^FORWARD_MONGODB2_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	MONGODB3_PORT=$$(grep '^FORWARD_MONGODB3_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	echo ""; \
	echo "📡 Individual Connections:"; \
	echo "   Primary:    mongodb://$$MONGODB_USERNAME:****@$$MONGODB1_HOST:$$MONGODB1_PORT/admin"; \
	echo "   Secondary1: mongodb://$$MONGODB_USERNAME:****@$$MONGODB2_HOST:$$MONGODB2_PORT/admin"; \
	echo "   Secondary2: mongodb://$$MONGODB_USERNAME:****@$$MONGODB3_HOST:$$MONGODB3_PORT/admin"; \
	echo ""; \
	echo "🔗 Cluster Connection String (RECOMMENDED):"; \
	echo "   mongodb://$$MONGODB_USERNAME:****@$$MONGODB1_HOST:$$MONGODB1_PORT,$$MONGODB2_HOST:$$MONGODB2_PORT,$$MONGODB3_HOST:$$MONGODB3_PORT/admin?replicaSet=rs"; \
	echo ""; \
	echo "⚠️  IMPORTANT: Always use the cluster connection string for proper"; \
	echo "   replica set functionality and automatic failover."; \
	echo ""; \
	echo "💡 Quick Actions:"; \
	echo "   🌐 make ui-enable    - Enable web interface"; \
	echo "   🐚 make shell        - Connect to MongoDB shell"; \
	echo "   📊 make status       - Check cluster status"
endef

help: ## Show this help message
	@echo '┌─────────────────────────────────────────────────────────────┐'
	@echo '│                MongoDB Cluster Management                   │'
	@echo '├─────────────────────────────────────────────────────────────┤'
	@echo '│ Usage: make [target]                                        │'
	@echo '└─────────────────────────────────────────────────────────────┘'
	@echo ''
	@echo 'Available Commands:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start Percona MongoDB cluster with dynamic keyfile
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                  Starting MongoDB Cluster                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@if [ ! -f .env ]; then \
		echo ""; \
		echo "🔧 Initial Setup Required"; \
		echo "──────────────────────────"; \
		echo "This appears to be your first time running the cluster."; \
		echo "Let's configure your MongoDB credentials and ports."; \
		echo ""; \
		echo "📝 MongoDB Credentials"; \
		echo "──────────────────────"; \
		bash -c 'read -p "Username [admin]: " username; username=$${username:-admin}; \
		echo ""; \
		echo "Password Configuration:"; \
		password=""; \
		while [ -z "$$password" ]; do \
			printf "Password [devpassword123]: "; \
			read -s temp_password; \
			echo ""; \
			if [ -z "$$temp_password" ]; then \
				temp_password="devpassword123"; \
			fi; \
			printf "Confirm Password: "; \
			read -s temp_confirm; \
			echo ""; \
			if [ -z "$$temp_confirm" ]; then \
				temp_confirm="devpassword123"; \
			fi; \
			if [ "$$temp_password" = "$$temp_confirm" ]; then \
				password="$$temp_password"; \
				echo "✅ Passwords match!"; \
			else \
				echo "❌ Passwords do not match. Please try again."; \
				echo ""; \
			fi; \
		done; \
		echo ""; \
		echo "📌 Port Configuration"; \
		echo "─────────────────────"; \
		echo "Format: port (e.g., 27017)"; \
		echo ""; \
		read -p "Primary Port [27017]: " mongodb1_port; \
		mongodb1_port=$${mongodb1_port:-27017}; \
		read -p "Secondary 1 Port [27018]: " mongodb2_port; \
		mongodb2_port=$${mongodb2_port:-27018}; \
		read -p "Secondary 2 Port [27019]: " mongodb3_port; \
		mongodb3_port=$${mongodb3_port:-27019}; \
		echo ""; \
		echo "🌐 Hostname Configuration"; \
		echo "─────────────────────────"; \
		echo "Configure hostnames for replica set members:"; \
		echo "  - Use actual hostnames (e.g., mongo1.mycompany.com)"; \
		echo "  - Each hostname must be resolvable from client machines"; \
		echo "  - Hostnames will be added to /etc/hosts for local resolution"; \
		echo ""; \
		read -p "Primary hostname [mongodb1]: " mongodb1_host; \
		mongodb1_host=$${mongodb1_host:-mongodb1}; \
		read -p "Secondary 1 hostname [mongodb2]: " mongodb2_host; \
		mongodb2_host=$${mongodb2_host:-mongodb2}; \
		while [ "$$mongodb2_host" = "$$mongodb1_host" ]; do \
			echo "❌ Hostname must be different from Primary"; \
			read -p "Secondary 1 hostname [mongodb2]: " mongodb2_host; \
			mongodb2_host=$${mongodb2_host:-mongodb2}; \
		done; \
		read -p "Secondary 2 hostname [mongodb3]: " mongodb3_host; \
		mongodb3_host=$${mongodb3_host:-mongodb3}; \
		while [ "$$mongodb3_host" = "$$mongodb1_host" ] || [ "$$mongodb3_host" = "$$mongodb2_host" ]; do \
			echo "❌ Hostname must be different from Primary and Secondary 1"; \
			read -p "Secondary 2 hostname [mongodb3]: " mongodb3_host; \
			mongodb3_host=$${mongodb3_host:-mongodb3}; \
		done; \
		echo ""; \
		echo "💾 Saving Configuration..."; \
		echo "## Percona MongoDB Cluster Configuration ##" > .env; \
		echo "" >> .env; \
		echo "# MongoDB credentials" >> .env; \
		echo "MONGODB_USERNAME=$$username" >> .env; \
		echo "MONGODB_PASSWORD=$$password" >> .env; \
		echo "" >> .env; \
		echo "# Exposed ports for each MongoDB instance" >> .env; \
		echo "# Format: [host:]port (use 0.0.0.0:port for external access)" >> .env; \
		echo "FORWARD_MONGODB1_PORT=$$mongodb1_port" >> .env; \
		echo "FORWARD_MONGODB2_PORT=$$mongodb2_port" >> .env; \
		echo "FORWARD_MONGODB3_PORT=$$mongodb3_port" >> .env; \
		echo "" >> .env; \
		echo "# Replica set hostname configuration" >> .env; \
		echo "MONGODB1_HOST=$$mongodb1_host" >> .env; \
		echo "MONGODB2_HOST=$$mongodb2_host" >> .env; \
		echo "MONGODB3_HOST=$$mongodb3_host" >> .env; \
		echo "" >> .env; \
		echo "# Deployment mode (setup includes initialization containers)" >> .env; \
		echo "DEPLOYMENT_MODE=setup" >> .env; \
		echo "" >> .env; \
		echo "# Note: Cluster keyfile is automatically generated dynamically" >> .env; \
		echo "✅ Configuration saved to .env"; \
		echo ""; \
		echo "📋 /etc/hosts Configuration Required"; \
		echo "───────────────────────────────────"; \
		echo "Copy and paste the following into your /etc/hosts file:"; \
		echo ""; \
		echo "127.0.0.1    $$mongodb1_host"; \
		echo "127.0.0.1    $$mongodb2_host"; \
		echo "127.0.0.1    $$mongodb3_host"; \
		echo ""; \
		echo "💡 On Windows: C:\\Windows\\System32\\drivers\\etc\\hosts"; \
		echo "💡 On Linux/Mac: /etc/hosts (requires sudo)"; \
		echo ""'; \
	fi
	@if grep -q "DEPLOYMENT_MODE=setup" .env 2>/dev/null; then \
		echo ""; \
		echo "🚀 Cluster Initialization"; \
		echo "─────────────────────────"; \
		echo "Starting cluster with first-time setup..."; \
		ln -sf docker-compose.setup.yml docker-compose.override.yml; \
		docker compose up -d; \
		echo ""; \
		echo "⏳ Initialization Progress"; \
		echo "──────────────────────────"; \
		setup_completed=false; \
		for i in $$(seq 1 30); do \
			if docker compose ps -a 2>/dev/null | grep -q "Exited (0)"; then \
				setup_completed=true; \
				unlink docker-compose.override.yml; \
				break; \
			fi; \
			printf "\r   Progress: [$$i/30] "; \
			for j in $$(seq 1 $$i); do printf "█"; done; \
			for j in $$(seq $$((i+1)) 30); do printf "░"; done; \
			sleep 2; \
		done; \
		echo ""; \
		if [ "$$setup_completed" = "true" ]; then \
			echo ""; \
			echo "🎯 Setup Complete!"; \
			echo "──────────────────"; \
			echo "Switching to production mode..."; \
			sed -i 's/DEPLOYMENT_MODE=setup/DEPLOYMENT_MODE=production/' .env; \
			COMPOSE_FILE="docker-compose.yml" docker compose up -d --remove-orphans; \
			echo "✅ Cluster is now running in production mode"; \
			echo ""; \
			echo "� Quick Actions"; \
			echo "────────────────"; \
			echo "   📊 make status        - Check cluster health"; \
			echo "   🔗 make test-connection - Verify connectivity"; \
			echo "   📈 make test-replica   - Check replica set status"; \
			echo ""; \
			$(call show_connection_info); \
		else \
			echo ""; \
			echo "⚠️  Extended Setup"; \
			echo "──────────────────"; \
			echo "Setup is taking longer than expected..."; \
			echo "Checking if cluster is already operational..."; \
			MONGODB1_CONTAINER=$(call get_container,mongodb1); \
			if [ -n "$$MONGODB1_CONTAINER" ] && docker exec $$MONGODB1_CONTAINER mongosh --eval "rs.status()" >/dev/null 2>&1; then \
				echo "🎯 Cluster is already operational!"; \
				echo "Switching to production mode..."; \
				unlink docker-compose.override.yml; \
				sed -i 's/DEPLOYMENT_MODE=setup/DEPLOYMENT_MODE=production/' .env; \
				COMPOSE_FILE="docker-compose.yml" docker compose up -d --remove-orphans; \
				echo "✅ Cluster is now running in production mode"; \
				echo ""; \
				echo "� Quick Actions"; \
				echo "────────────────"; \
				echo "   📊 make status        - Check cluster health"; \
				echo "   🔗 make test-connection - Verify connectivity"; \
				echo "   📈 make test-replica   - Check replica set status"; \
				echo ""; \
				$(call show_connection_info); \
			else \
				echo "❌ Setup failed or timed out"; \
				echo "   💡 Try: make logs"; \
			fi; \
		fi; \
	else \
		echo ""; \
		echo "🚀 Production Mode"; \
		echo "─────────────────"; \
		echo "Starting cluster in production mode..."; \
		docker compose up -d --remove-orphans; \
		echo "⏳ Validating replica set..."; \
		sleep 10; \
		MONGODB1_CONTAINER=$(call get_container,mongodb1); \
		if [ -n "$$MONGODB1_CONTAINER" ]; then \
			MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
			MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
			if ! docker exec $$MONGODB1_CONTAINER mongosh --eval "rs.status()" --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD >/dev/null 2>&1; then \
				echo ""; \
				echo "🔧 Replica Set Setup Required"; \
				echo "─────────────────────────────"; \
				echo "Replica set not initialized. Switching to setup mode..."; \
				sed -i 's/DEPLOYMENT_MODE=production/DEPLOYMENT_MODE=setup/' .env; \
				echo "⚠️  Please run 'make start' again to complete setup"; \
				docker compose down; \
				exit 1; \
			else \
				echo "✅ Replica set is ready"; \
				$(call show_connection_info); \
			fi; \
		else \
			echo "❌ Failed to start containers"; \
		fi; \
	fi

stop: ## Stop Percona MongoDB cluster
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                  Stopping MongoDB Cluster                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@docker compose down
	@echo "✅ Cluster stopped successfully"

restart: stop start ## Restart Percona MongoDB cluster

logs: ## Show logs for all services
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                        Cluster Logs                         │"
	@echo "│                    Press Ctrl+C to exit                     │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@docker compose logs -f

clean: ## Clean up environment (removes volumes)
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                     Environment Cleanup                     │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "⚠️  WARNING: This will permanently remove:"
	@echo "   • All MongoDB data volumes"
	@echo "   • All container instances"
	@echo "   • Orphaned resources"
	@echo ""
	@echo "Are you sure you want to continue? [Y/n]"; \
	read -r REPLY; \
	if [ "$$REPLY" = "n" ] || [ "$$REPLY" = "N" ]; then \
		echo ""; \
		echo "❌ Operation cancelled"; \
	else \
		echo ""; \
		echo "🧹 Cleaning up..."; \
		docker compose down -v --remove-orphans; \
		if [ -f .env ]; then \
			sed -i 's/DEPLOYMENT_MODE=production/DEPLOYMENT_MODE=setup/' .env; \
			echo "✅ Reset deployment mode to setup"; \
		fi; \
		echo "✅ Environment cleaned successfully!"; \
		echo ""; \
		echo "💡 Next: Run 'make start' to create a fresh cluster"; \
	fi

test-connection: ## Test MongoDB connections
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                   Connection Test Results                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@if [ -f .env ]; then \
		MONGODB1_PORT=$$(grep '^FORWARD_MONGODB1_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
		MONGODB2_PORT=$$(grep '^FORWARD_MONGODB2_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
		MONGODB3_PORT=$$(grep '^FORWARD_MONGODB3_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
		EXPRESS_PORT=$$(grep '^FORWARD_MONGODB_EXPRESS_PORT=' .env 2>/dev/null | cut -d'=' -f2 | sed 's/.*://' || echo "8081"); \
	else \
		MONGODB1_PORT=27017; \
		MONGODB2_PORT=27018; \
		MONGODB3_PORT=27019; \
		EXPRESS_PORT=8081; \
	fi; \
	echo ""; \
	echo "📊 MongoDB Nodes"; \
	echo "────────────────"; \
	printf "   Primary (port $$MONGODB1_PORT)............ "; \
	timeout 5 bash -c "until nc -z localhost $$MONGODB1_PORT; do sleep 1; done" && echo "✅ Online" || echo "❌ Offline"; \
	printf "   Secondary 1 (port $$MONGODB2_PORT)........ "; \
	timeout 5 bash -c "until nc -z localhost $$MONGODB2_PORT; do sleep 1; done" && echo "✅ Online" || echo "❌ Offline"; \
	printf "   Secondary 2 (port $$MONGODB3_PORT)........ "; \
	timeout 5 bash -c "until nc -z localhost $$MONGODB3_PORT; do sleep 1; done" && echo "✅ Online" || echo "❌ Offline"; \
	echo ""; \
	echo "🌐 Web Interface"; \
	echo "───────────────"; \
	if docker compose ps mongo-express | grep -q "Up"; then \
		printf "   Mongo Express (port $$EXPRESS_PORT)....... "; \
		timeout 5 bash -c "until nc -z localhost $$EXPRESS_PORT; do sleep 1; done" && echo "✅ Online" || echo "❌ Offline"; \
	else \
		echo "   Mongo Express........................ ⚪ Disabled"; \
		echo "                                          💡 Enable with 'make ui-enable'"; \
	fi; \
	echo ""

status: ## Show cluster status
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                   MongoDB Cluster Status                    │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@if [ -f .env ]; then \
		DEPLOYMENT_MODE=$$(grep '^DEPLOYMENT_MODE=' .env | cut -d'=' -f2); \
		if [ "$$DEPLOYMENT_MODE" = "production" ]; then \
			echo ""; \
			MONGODB1_CONTAINER=$(call get_container,mongodb1); \
			if [ ! -z "$$MONGODB1_CONTAINER" ]; then \
				MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
				MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
				echo "📊 Replica Set Status"; \
				echo "─────────────────────"; \
				RS_STATUS=$$(docker exec $$MONGODB1_CONTAINER mongosh --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health})).forEach(m => print(m.name + ': ' + m.state + ' (health: ' + m.health + ')'))" --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --quiet 2>/dev/null); \
				if [ $$? -eq 0 ]; then \
					echo "$$RS_STATUS" | sed 's/^/   /'; \
				else \
					echo "   ⚠️  Replica set initializing..."; \
					echo "      This is normal during startup. Try again in a moment."; \
				fi; \
				echo ""; \
				$(call show_connection_info); \
			else \
				echo ""; \
				echo "❌ Status: Offline"; \
				echo "─────────────────"; \
				echo "   MongoDB containers are not running"; \
				echo "   💡 Try: make start"; \
			fi \
		else \
			echo ""; \
			echo "⚠️  Status: Setup Mode"; \
			echo "──────────────────────"; \
			echo "   Cluster is in setup mode"; \
			echo "   💡 Try: make start"; \
		fi \
	else \
		echo ""; \
		echo "❌ Status: Not Configured"; \
		echo "─────────────────────────"; \
		echo "   No configuration found"; \
		echo "   💡 Try: make start"; \
	fi

test-replica: ## Test replica set status
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                  Replica Set Health Check                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@MONGODB1_CONTAINER=$(call get_container,mongodb1); \
	if [ -z "$$MONGODB1_CONTAINER" ]; then \
		echo ""; \
		echo "❌ Test Failed"; \
		echo "──────────────"; \
		echo "   MongoDB container not found"; \
		echo "   💡 Try: make start"; \
		exit 1; \
	fi; \
	echo ""; \
	MONGODB1_PORT=$$(grep '^FORWARD_MONGODB1_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	if [ -f .env ]; then \
		MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
		MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
		echo "📊 Replica Set Members"; \
		echo "──────────────────────"; \
		RS_STATUS=$$(docker exec $$MONGODB1_CONTAINER mongosh  --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --port $$MONGODB1_PORT --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health})).forEach(m => print(m.name + ': ' + m.state + ' (health: ' + m.health + ')'))" --quiet 2>/dev/null); \
		if [ $$? -eq 0 ]; then \
			echo "$$RS_STATUS" | sed 's/^/   /'; \
			echo ""; \
			echo "✅ Replica set is healthy"; \
		else \
			echo "   ❌ Failed to connect or replica set not initialized"; \
		fi; \
	else \
		echo "📊 Replica Set Members (default credentials)"; \
		echo "────────────────────────────────────────────"; \
		RS_STATUS=$$(docker exec $$MONGODB1_CONTAINER mongosh  --username admin --password devpassword123 --port $$MONGODB1_PORT --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr, health: m.health})).forEach(m => print(m.name + ': ' + m.state + ' (health: ' + m.health + ')'))" --quiet 2>/dev/null); \
		if [ $$? -eq 0 ]; then \
			echo "$$RS_STATUS" | sed 's/^/   /'; \
			echo ""; \
			echo "✅ Replica set is healthy"; \
		else \
			echo "   ❌ Failed to connect or replica set not initialized"; \
		fi; \
	fi

ui-enable: ## Enable Mongo Express web UI
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│               Enable Web Interface                          │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@if ! grep -q "FORWARD_MONGODB_EXPRESS_PORT" .env 2>/dev/null; then \
		echo "📌 Web UI Port Configuration"; \
		echo "───────────────────────────"; \
		echo "Format: [host:]port (e.g., 8081 or 0.0.0.0:8081 for external access)"; \
		echo ""; \
		read -p "Mongo Express Web UI Port [8081]: " express_port; \
		express_port=$${express_port:-8081}; \
		echo ""; \
		echo "💾 Saving configuration..."; \
		echo "# Web UI Configuration" >> .env; \
		echo "FORWARD_MONGODB_EXPRESS_PORT=$$express_port" >> .env; \
		echo "✅ Port configuration saved"; \
		echo ""; \
	fi
	@echo "🚀 Deploying Mongo Express..."
	@echo "# Optional Mongo Express Web UI" > docker-compose.override.yml
	@echo "# This file is automatically loaded by docker compose" >> docker-compose.override.yml
	@echo "# To disable, rename this file or delete it" >> docker-compose.override.yml
	@echo "" >> docker-compose.override.yml
	@echo "services:" >> docker-compose.override.yml
	@echo "  mongo-express:" >> docker-compose.override.yml
	@echo "    image: mongo-express:latest" >> docker-compose.override.yml
	@echo "    restart: unless-stopped" >> docker-compose.override.yml
	@echo "    hostname: mongo-express" >> docker-compose.override.yml
	@echo "    ports:" >> docker-compose.override.yml
	@echo "      - \"\$${FORWARD_MONGODB_EXPRESS_PORT}:8081\"" >> docker-compose.override.yml
	@echo "    depends_on:" >> docker-compose.override.yml
	@echo "      mongodb1:" >> docker-compose.override.yml
	@echo "        condition: service_healthy" >> docker-compose.override.yml
	@echo "      mongodb2:" >> docker-compose.override.yml
	@echo "        condition: service_healthy" >> docker-compose.override.yml
	@echo "      mongodb3:" >> docker-compose.override.yml
	@echo "        condition: service_healthy" >> docker-compose.override.yml
	@echo "    environment:" >> docker-compose.override.yml
	@echo "      ME_CONFIG_MONGODB_ADMINUSERNAME: \$${MONGODB_USERNAME}" >> docker-compose.override.yml
	@echo "      ME_CONFIG_MONGODB_ADMINPASSWORD: \$${MONGODB_PASSWORD}" >> docker-compose.override.yml
	@echo "      ME_CONFIG_MONGODB_URL: 'mongodb://\$${MONGODB_USERNAME}:\$${MONGODB_PASSWORD}@\$${MONGODB1_HOST}:27017,\$${MONGODB2_HOST}:27017,\$${MONGODB3_HOST}:27017/?replicaSet=rs'" >> docker-compose.override.yml
	@echo "      ME_CONFIG_MONGODB_ENABLE_ADMIN: 'true'" >> docker-compose.override.yml
	@echo "      ME_CONFIG_BASICAUTH_USERNAME: \$${MONGODB_USERNAME}" >> docker-compose.override.yml
	@echo "      ME_CONFIG_BASICAUTH_PASSWORD: \$${MONGODB_PASSWORD}" >> docker-compose.override.yml
	@echo "    networks:" >> docker-compose.override.yml
	@echo "      - mongo-net" >> docker-compose.override.yml
	@docker compose up -d mongo-express
	@EXPRESS_PORT=$$(grep '^FORWARD_MONGODB_EXPRESS_PORT=' .env 2>/dev/null | cut -d'=' -f2 | sed 's/.*://' || echo "8081"); \
	echo ""; \
	echo "✅ Mongo Express enabled successfully!"; \
	echo ""; \
	echo "🌐 Web Interface"; \
	echo "───────────────"; \
	echo "   URL: http://localhost:$$EXPRESS_PORT"; \
	echo "   💡 Use your MongoDB credentials to log in"

ui-disable: ## Disable Mongo Express web UI
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│              Disable Web Interface                          │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🛑 Stopping Mongo Express..."
	@docker compose stop mongo-express 2>/dev/null || true
	@docker compose rm -f mongo-express 2>/dev/null || true
	@if [ -f docker-compose.override.yml ]; then \
		mv docker-compose.override.yml docker-compose.override.yml.disabled; \
		echo "📁 Configuration preserved as .disabled"; \
	fi
	@echo "✅ Mongo Express disabled successfully"
	@echo ""
	@echo "💡 To re-enable: make ui-enable"

ui-restart: ## Restart web UI
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│               Restart Web Interface                         │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@echo ""
	@echo "🔄 Restarting Mongo Express..."
	@docker compose restart mongo-express && echo "✅ Mongo Express restarted successfully" || echo "❌ Mongo Express not running"

shell: ## Connect to MongoDB shell on primary node
	@echo "┌─────────────────────────────────────────────────────────────┐"
	@echo "│                  MongoDB Shell Connection                   │"
	@echo "└─────────────────────────────────────────────────────────────┘"
	@MONGODB1_CONTAINER=$(call get_container,mongodb1); \
	if [ -z "$$MONGODB1_CONTAINER" ]; then \
		echo ""; \
		echo "❌ Connection Failed"; \
		echo "────────────────────"; \
		echo "   MongoDB container not found"; \
		echo "   💡 Try: make start"; \
		exit 1; \
	fi; \
	echo ""; \
	MONGODB1_PORT=$$(grep '^FORWARD_MONGODB1_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	if [ -f .env ]; then \
		MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
		MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
		echo "🔗 Connecting to primary MongoDB as $$MONGODB_USERNAME..."; \
		echo ""; \
		docker exec -it $$MONGODB1_CONTAINER mongosh --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD --port $$MONGODB1_PORT; \
	else \
		echo "🔗 Connecting to primary MongoDB with default credentials..."; \
		echo ""; \
		docker exec -it $$MONGODB1_CONTAINER mongosh --username admin --password devpassword123 --port $$MONGODB1_PORT; \
	fi
