.PHONY: setup update serve clean test lint build docker-build docker-run docker-compose-up docker-compose-down docker-clean

# Default target
all: setup

# Install dependencies
setup:
	@echo "🔧 Installing Crystal dependencies..."
	shards install

# Collect and update project data
update:
	@echo "📊 Collecting project data..."
	crystal run src/collect_data.cr -- $(ARGS)

# Collect data with specific GitHub user
update-user:
	@echo "📊 Collecting project data for $(USER)..."
	crystal run src/collect_data.cr -- --github-user=$(USER)

# Show help for data collection
update-help:
	@echo "📊 Data collection help:"
	crystal run src/collect_data.cr -- --help

# Start the web server
serve:
	@echo "🚀 Starting visualization server..."
	crystal run src/server.cr

# Build the binaries
build:
	@echo "🏗️ Building binaries..."
	shards build

# Run tests
test:
	@echo "🧪 Running tests..."
	crystal spec

# Run linter
lint:
	@echo "🔍 Running linter..."
	@if command -v ameba >/dev/null 2>&1; then \
		ameba --fix; \
	else \
		echo "Ameba not found. Install with: shards install"; \
	fi

# Clean up
clean:
	@echo "🧹 Cleaning up..."
	rm -rf bin/
	rm -f public/projects.json

# Full setup and run
run: setup update serve

# Development workflow
dev: setup update
	@echo "🔄 Development mode: will update data and start server"
	crystal run src/server.cr

# Examples of usage with arguments
examples:
	@echo "📚 Usage examples:"
	@echo "  make update                                    # Use defaults"
	@echo "  make update ARGS='--github-user=myuser'       # Custom user"
	@echo "  make update ARGS='--max-depth=2'              # Shallow scan"
	@echo "  make update ARGS='--max-projects=100'         # Fewer projects"
	@echo "  make update-user USER=myuser                  # Using update-user target"
	@echo "  make update-help                              # Show help"
	@echo ""
	@echo "📄 Environment variables also work:"
	@echo "  GITHUB_USER=myuser crystal src/collect_data.cr"
	@echo "  MAX_DEPTH=2 crystal src/collect_data.cr"

# Docker targets
docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t rpu:latest .

docker-run:
	@echo "🚀 Running Docker container..."
	docker run --rm -it -p 3000:3000 \
		-e GITHUB_USER=$(GITHUB_USER) \
		-e MAX_DEPTH=$(MAX_DEPTH) \
		-e MAX_PROJECTS=$(MAX_PROJECTS) \
		-e RATE_LIMIT_DELAY=$(RATE_LIMIT_DELAY) \
		-v $(PWD)/data:/app/public \
		rpu:latest

docker-compose-up:
	@echo "🐳 Starting services with docker-compose..."
	docker-compose up -d

docker-compose-down:
	@echo "🛑 Stopping services..."
	docker-compose down

docker-compose-logs:
	@echo "📋 Showing logs..."
	docker-compose logs -f

docker-compose-collect:
	@echo "📊 Running data collection..."
	docker-compose run --rm rpu-collect

docker-clean:
	@echo "🧹 Cleaning Docker resources..."
	docker rmi rpu:latest || true
	docker-compose down --v --rmi all || true
	docker system prune -f
