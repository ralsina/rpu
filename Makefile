.PHONY: setup build test lint clean examples

# Default target
all: setup

# Install dependencies
setup:
	@echo "🔧 Installing Crystal dependencies..."
	shards install

# Build the data collection binary
build:
	@echo "🏗️ Building data collection binary..."
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

# Run data collection locally (development only)
collect:
	@echo "📊 Collecting project data locally..."
	crystal run src/collect_data.cr -- $(ARGS)

# Show usage examples
examples:
	@echo "📚 Local development examples:"
	@echo "  make collect                                    # Use defaults"
	@echo "  make collect ARGS='--github-user=myuser'       # Custom user"
	@echo "  make collect ARGS='--max-depth=2'              # Shallow scan"
	@echo "  make collect ARGS='--max-projects=50'          # Fewer projects"
	@echo ""
	@echo "🌐 For production deployment:"
	@echo "  Fork this repository and enable GitHub Pages"
	@echo "  The workflow will automatically build and deploy your visualization"