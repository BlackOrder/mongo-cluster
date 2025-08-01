.PHONY: help start stop restart logs clean test-connection status ui-enable ui-disable ui-restart

# Helper function to display connection information
define show_connection_info
	@echo "🔗 Connection Information:"; \
	MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
	MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
	MONGODB1_PORT=$$(grep '^FORWARD_MONGODB1_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	MONGODB2_PORT=$$(grep '^FORWARD_MONGODB2_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	MONGODB3_PORT=$$(grep '^FORWARD_MONGODB3_PORT=' .env | cut -d'=' -f2 | sed 's/.*://'); \
	echo "Primary: mongodb://$$MONGODB_USERNAME:$$MONGODB_PASSWORD@localhost:$$MONGODB1_PORT/admin"; \
	echo "Replica 1: mongodb://$$MONGODB_USERNAME:$$MONGODB_PASSWORD@localhost:$$MONGODB2_PORT/admin"; \
	echo "Replica 2: mongodb://$$MONGODB_USERNAME:$$MONGODB_PASSWORD@localhost:$$MONGODB3_PORT/admin"; \
	echo ""; \
	echo "Cluster Connection String:"; \
	echo "mongodb://$$MONGODB_USERNAME:$$MONGODB_PASSWORD@localhost:$$MONGODB1_PORT,localhost:$$MONGODB2_PORT,localhost:$$MONGODB3_PORT/admin?replicaSet=rs"; \
	echo ""; \
	echo "🌐 Optional: Enable web UI with 'make ui-enable' for database management"
endef

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

start: ## Start Percona MongoDB cluster with dynamic keyfile
	@echo "Starting Percona MongoDB cluster..."
	@if [ ! -f .env ]; then \
		echo "🔧 Setting up MongoDB cluster for the first time..."; \
		echo ""; \
		echo "📝 Please provide MongoDB credentials (or press Enter for defaults):"; \
		echo ""; \
		bash -c 'read -p "MongoDB Username [admin]: " username; username=$${username:-admin}; \
		echo ""; \
		echo "Setting password (press Enter twice for default '\''devpassword123'\''):"; \
		password=""; \
		while [ -z "$$password" ]; do \
			printf "MongoDB Password [devpassword123]: "; \
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
				echo "❌ Passwords don'\''t match. Please try again."; \
				echo ""; \
			fi; \
		done; \
		echo ""; \
		echo "📌 Port Configuration (press Enter for defaults):"; \
		echo "   Format: [host:]port (e.g., 27017 or 0.0.0.0:27017 for external access)"; \
		echo ""; \
		read -p "MongoDB Primary Port [27017]: " mongodb1_port; \
		mongodb1_port=$${mongodb1_port:-27017}; \
		read -p "MongoDB Secondary 1 Port [27018]: " mongodb2_port; \
		mongodb2_port=$${mongodb2_port:-27018}; \
		read -p "MongoDB Secondary 2 Port [27019]: " mongodb3_port; \
		mongodb3_port=$${mongodb3_port:-27019}; \
		echo ""; \
		echo "Creating .env file with your settings..."; \
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
		echo "# Deployment mode (setup includes initialization containers)" >> .env; \
		echo "DEPLOYMENT_MODE=setup" >> .env; \
		echo "" >> .env; \
		echo "# Note: Cluster keyfile is automatically generated dynamically" >> .env; \
		echo "✅ Created .env file with your credentials"; \
		echo "";'; \
	fi
	@if grep -q "DEPLOYMENT_MODE=setup" .env 2>/dev/null; then \
		echo "🚀 Starting cluster with initialization (first-time setup)..."; \
		ln -sf docker-compose.setup.yml docker-compose.override.yml; \
		docker compose up -d; \
		echo "⏳ Waiting for cluster initialization to complete..."; \
		setup_completed=false; \
		for i in $$(seq 1 30); do \
			if docker compose ps -a 2>/dev/null | grep -q "Exited (0)"; then \
				setup_completed=true; \
				unlink docker-compose.override.yml; \
				break; \
			fi; \
			echo "  Checking setup progress... ($$i/30)"; \
			sleep 2; \
		done; \
		if [ "$$setup_completed" = "true" ]; then \
			echo "🎯 Cluster initialization completed successfully!"; \
			echo "🔄 Switching to production mode..."; \
			sed -i 's/DEPLOYMENT_MODE=setup/DEPLOYMENT_MODE=production/' .env; \
			COMPOSE_FILE="docker-compose.yml" docker compose up -d --remove-orphans; \
			echo "✅ Cluster is now running in production mode"; \
			echo ""; \
			echo "📊 Use 'make status' to check cluster health"; \
			echo "🔗 Use 'make test-connection' to verify connectivity"; \
			echo "📈 Use 'make test-replica' to check replica set status"; \
			echo ""; \
			$(call show_connection_info); \
		else \
			echo "⚠️  Setup taking longer than expected. Checking if cluster is already operational..."; \
			if docker exec mongo-cluster-mongodb1-1 mongosh --eval "rs.status()" >/dev/null 2>&1; then \
				echo "🎯 Cluster is already operational! Switching to production mode..."; \
				docker rm -f mongo-cluster-keyfile-init-1 mongo-cluster-mongo-setup-1 2>/dev/null || true; \
				sed -i 's/DEPLOYMENT_MODE=setup/DEPLOYMENT_MODE=production/' .env; \
				echo "✅ Cluster is now running in production mode"; \
				echo ""; \
				$(call show_connection_info); \
			else \
				echo "❌ Setup failed or timed out. Check logs with 'make logs'"; \
			fi; \
		fi; \
	else \
		echo "🚀 Starting cluster in production mode..."; \
		docker compose up -d --remove-orphans; \
	fi

stop: ## Stop Percona MongoDB cluster
	@echo "Stopping Percona MongoDB cluster..."
	docker compose down

restart: stop start ## Restart Percona MongoDB cluster

logs: ## Show logs for all services
	docker compose logs -f

clean: ## Clean up environment (removes volumes)
	@echo "⚠️  This will remove all MongoDB data volumes!"
	@echo "Are you sure? [Y/n]"; \
	read -r REPLY; \
	if [ "$$REPLY" = "n" ] || [ "$$REPLY" = "N" ]; then \
		echo "Operation cancelled."; \
	else \
		docker compose down -v --remove-orphans; \
		echo "Environment cleaned!"; \
	fi

test-connection: ## Test MongoDB connections
	@echo "Testing MongoDB connections..."
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
	echo "Testing Primary (port $$MONGODB1_PORT)..."; \
	timeout 5 bash -c "until nc -z localhost $$MONGODB1_PORT; do sleep 1; done" && echo "✅ Primary is accessible" || echo "❌ Primary is not accessible"; \
	echo "Testing Secondary 1 (port $$MONGODB2_PORT)..."; \
	timeout 5 bash -c "until nc -z localhost $$MONGODB2_PORT; do sleep 1; done" && echo "✅ Secondary 1 is accessible" || echo "❌ Secondary 1 is not accessible"; \
	echo "Testing Secondary 2 (port $$MONGODB3_PORT)..."; \
	timeout 5 bash -c "until nc -z localhost $$MONGODB3_PORT; do sleep 1; done" && echo "✅ Secondary 2 is accessible" || echo "❌ Secondary 2 is not accessible"; \
	if docker compose ps mongo-express | grep -q "Up"; then \
		echo "Testing Mongo Express (port $$EXPRESS_PORT)..."; \
		timeout 5 bash -c "until nc -z localhost $$EXPRESS_PORT; do sleep 1; done" && echo "✅ Mongo Express is accessible" || echo "❌ Mongo Express is not accessible"; \
	else \
		echo "ℹ️  Mongo Express is disabled (use 'make ui-enable' to enable)"; \
	fi

status: ## Show cluster status
	@echo "Percona MongoDB Cluster Status:"
	@docker compose ps

test-replica: ## Test replica set status
	@echo "Testing replica set status..."
	@if [ -f .env ]; then \
		MONGODB_USERNAME=$$(grep '^MONGODB_USERNAME=' .env | cut -d'=' -f2); \
		MONGODB_PASSWORD=$$(grep '^MONGODB_PASSWORD=' .env | cut -d'=' -f2); \
		docker exec mongo-cluster-mongodb1-1 mongosh --eval "rs.status()" --username $$MONGODB_USERNAME --password $$MONGODB_PASSWORD || echo "❌ Failed to connect to cluster"; \
	else \
		docker exec mongo-cluster-mongodb1-1 mongosh --eval "rs.status()" --username admin --password devpassword123 || echo "❌ Failed to connect to cluster"; \
	fi

ui-enable: ## Enable Mongo Express web UI
	@echo "Enabling Mongo Express web UI..."
	@echo ""
	@if ! grep -q "FORWARD_MONGODB_EXPRESS_PORT" .env 2>/dev/null; then \
		echo "📌 Web UI Port Configuration:"; \
		echo "   Format: [host:]port (e.g., 8081 or 0.0.0.0:8081 for external access)"; \
		echo ""; \
		read -p "Mongo Express Web UI Port [8081]: " express_port; \
		express_port=$${express_port:-8081}; \
		echo ""; \
		echo "# Web UI Configuration" >> .env; \
		echo "FORWARD_MONGODB_EXPRESS_PORT=$$express_port" >> .env; \
		echo "✅ Added web UI port configuration to .env"; \
		echo ""; \
	fi
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
	@echo "      ME_CONFIG_MONGODB_URL: 'mongodb://\$${MONGODB_USERNAME}:\$${MONGODB_PASSWORD}@mongodb1:27017,mongodb2:27017,mongodb3:27017/?replicaSet=rs'" >> docker-compose.override.yml
	@echo "      ME_CONFIG_MONGODB_ENABLE_ADMIN: 'true'" >> docker-compose.override.yml
	@echo "      ME_CONFIG_BASICAUTH_USERNAME: \$${MONGODB_USERNAME}" >> docker-compose.override.yml
	@echo "      ME_CONFIG_BASICAUTH_PASSWORD: \$${MONGODB_PASSWORD}" >> docker-compose.override.yml
	@echo "    networks:" >> docker-compose.override.yml
	@echo "      - mongo-net" >> docker-compose.override.yml
	@docker compose up -d mongo-express
	@EXPRESS_PORT=$$(grep '^FORWARD_MONGODB_EXPRESS_PORT=' .env 2>/dev/null | cut -d'=' -f2 | sed 's/.*://' || echo "8081"); \
	echo "✅ Mongo Express enabled at http://localhost:$$EXPRESS_PORT"

ui-disable: ## Disable Mongo Express web UI
	@echo "Disabling Mongo Express web UI..."
	@docker compose stop mongo-express 2>/dev/null || true
	@docker compose rm -f mongo-express 2>/dev/null || true
	@if [ -f docker-compose.override.yml ]; then \
		mv docker-compose.override.yml docker-compose.override.yml.disabled; \
		echo "✅ Moved docker-compose.override.yml to .disabled"; \
	fi
	@echo "✅ Mongo Express disabled"

ui-restart: ## Restart web UI
	@echo "Restarting Mongo Express..."
	@docker compose restart mongo-express || echo "Mongo Express not running"
