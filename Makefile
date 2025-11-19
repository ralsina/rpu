.PHONY: setup update serve clean test lint build

# Default target
all: setup

# Install dependencies
setup:
	@echo "🔧 Installing Crystal dependencies..."
	shards install

# Collect and update project data
update:
	@echo "📊 Collecting project data..."
	crystal run src/collect_data.cr

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