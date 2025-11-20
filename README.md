# Crystal Projects Visualization (RPU)

🔮 An interactive visualization tool for exploring Crystal project dependencies and metrics.

## Overview

This project creates a beautiful, interactive web visualization showing:
- **Project nodes** sized by Lines of Code (LOC)
- **Colors** representing recency of modifications (warmer = more recent)
- **Dependency connections** showing which projects use which
- **Interactive features** like zoom, tooltips, and clickable nodes

## Features

- 📊 **Automatic data collection** - Scans GitHub for Crystal projects with `shard.yml` using GitHub API
- 📈 **Dependency graphing** - Shows internal project dependencies
- 🎨 **Beautiful visualization** - Uses D3.js force-directed graph with pico.css styling
- 🔄 **Live updates** - Re-run data collection to get latest project information
- 📱 **Responsive design** - Works on desktop and mobile devices
- ⚡ **Fast** - Built with Crystal for performance

## Requirements

### Local Development
- [Crystal](https://crystal-lang.org/) (>= 1.0)
- [GitHub CLI](https://cli.github.com/) (gh) - for repository discovery
- Git - for cloning repositories

### Docker Deployment (Recommended)
- [Docker](https://www.docker.com/) (>= 20.10)
- [Docker Compose](https://docs.docker.com/compose/) (>= 2.0)

## Quick Start

### 🐳 Docker Deployment (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ralsina/rpu.git
   cd rpu
   ```

2. **Configure environment (optional):**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Start with Docker Compose:**
   ```bash
   make docker-compose-up
   # Or: docker-compose up -d
   ```

4. **Collect project data:**
   ```bash
   make docker-compose-collect
   # Or: docker-compose run --rm rpu-collect
   ```

5. **Open your browser:**
   Visit `http://localhost:3000` to see the visualization!

### 💻 Local Development

1. **Clone and setup:**
   ```bash
   git clone https://github.com/ralsina/rpu.git
   cd rpu
   make setup
   ```

2. **Collect project data:**
   ```bash
   make update
   ```
   This will:
   - Discover all Crystal repositories for your GitHub user via API
   - Parse dependencies from `shard.yml` files
   - Calculate LOC using tokei
   - Generate project data JSON

3. **Start the visualization:**
   ```bash
   make serve
   ```

4. **Open your browser:**
   Visit `http://localhost:3000` to see the visualization!

## Usage

### Commands

#### Docker Commands
- `make docker-build` - Build Docker image
- `make docker-run` - Run Docker container
- `make docker-compose-up` - Start services with Docker Compose
- `make docker-compose-down` - Stop services
- `make docker-compose-collect` - Run data collection
- `make docker-compose-logs` - View logs
- `make docker-clean` - Clean Docker resources

#### Local Development Commands
- `make setup` - Install Crystal dependencies
- `make update` - Collect fresh project data
- `make serve` - Start the web server
- `make run` - Full workflow: setup + update + serve
- `make dev` - Development mode (updates data then starts server)
- `make build` - Build binaries
- `make test` - Run tests
- `make lint` - Run linter with auto-fix
- `make clean` - Clean up generated files

### Manual Usage

```bash
# Install dependencies
shards install

# Collect data
crystal run src/collect_data.cr

# Start server
crystal run src/server.cr
```

### Configuration

The application supports multiple configuration methods:

#### Environment Variables (Docker)
```bash
GITHUB_USER=ralsina          # GitHub username to scan
MAX_DEPTH=3                  # Maximum recursion depth for dependencies
MAX_PROJECTS=500             # Maximum total projects to process
RATE_LIMIT_DELAY=0.1         # Seconds to wait between API calls
DATA_FILE=/app/public/projects.json  # Output JSON file path
PORT=3000                    # Web server port
```

#### Command Line Arguments (Local)
```bash
crystal run src/collect_data.cr -- --github-user=myuser --max-depth=2
```

#### Configuration Files
Create `.rpu.yaml` in the project directory or `~/.rpu.yaml` globally:
```yaml
github_user: "ralsina"
max_depth: 3
max_projects: 500
rate_limit_delay: 0.1
data_file: "public/projects.json"
```

Configuration precedence: Command Line > Environment Variables > Config File > Defaults

## Visualization Features

### Interactive Elements
- **Click nodes** - Opens project repository in new tab
- **Hover** - Shows project details (LOC, description, activity status, fork status)
- **Zoom/Pan** - Mouse wheel and drag navigation
- **Toggle labels** - Show/hide project names
- **Reset zoom** - Return to default view
- **Improved layout** - Better positioning of disconnected nodes with optimized force simulation

### Visual Encoding
- **Node shape** - 🟢 Circles for original projects, 🔄 Hexagons for forked projects, 🔶 Triangles for external dependencies
- **Node size** - Crystal code bytes for your projects (larger = more code), fixed size for external dependencies
- **Node color** - Activity level for your projects (green = recent, red = old), light blue for external dependencies
  - 🟢 **Green** - Modified within last month (actively maintained)
  - 🟡 **Yellow-green** - Modified within 3 months (recently active)
  - 🟠 **Orange** - Modified within 6 months (moderately active)
  - 🔶 **Dark orange** - Modified within 1 year (inactive)
  - 🔴 **Red** - Modified over 1 year ago (stale)
- **Node border** - Orange for forks, black for original projects, blue for external dependencies
- **Arrows** - Dependency direction (A → B means A uses B)
  - Solid lines = internal dependencies between your projects
  - Dashed lines = external dependencies to third-party libraries
- **Statistics** - Total projects, LOC, and dependencies

### Dependency Types
- **Internal dependencies** - Links between your own projects
- **External dependencies** - Links to third-party Crystal shards
- **Fork Detection** - Automatically identifies forked repositories via GitHub API

### External Dependency Detection
- Automatically discovers all Crystal dependencies from shard.yml files
- Separates internal dependencies (your projects) from external dependencies (third-party shards)
- External dependencies are shown as triangles with blue styling
- Creates a complete dependency ecosystem view

## Project Structure

```
rpu/
├── src/
│   ├── collect_data.cr  # Data collection script
│   └── server.cr        # Web server with embedded HTML
├── projects/            # Cloned repositories (auto-generated)
├── public/
│   └── projects.json    # Generated project data
├── shard.yml           # Crystal dependencies
├── Makefile            # Convenience commands
└── README.md           # This file
```

## Data Collection Process

1. **Repository Discovery** - Uses GitHub API to find repos with `shard.yml`
2. **API-based Access** - Retrieves repository and file contents via GitHub API (no cloning required)
3. **Dependency Parsing** - Extracts Crystal dependencies from `shard.yml` files
4. **Metrics Calculation** - Uses tokei for LOC, git for modification dates
5. **Cross-referencing** - Maps internal dependencies between projects
6. **JSON Generation** - Creates `public/projects.json` for visualization

## Development

### Adding Features

- **New metrics** - Modify `Project` struct and update `collect_data.cr`
- **Visualization changes** - Edit the HTML/JavaScript in `src/server.cr`
- **New endpoints** - Add routes in `src/server.cr`

### Testing

```bash
make test
```

### Linting

```bash
make lint
```

## GitHub Actions Deployment (Automatic)

The project includes a fully automated GitHub Actions workflow that:

### 🚀 **Features**
- **Daily Updates**: Automatically runs every day at 2 AM UTC
- **Manual Triggers**: Can be triggered manually from GitHub Actions tab
- **Smart Triggers**: Runs on code changes to `src/`, `shard.yml`, or workflow files
- **GitHub Token**: Uses repository's GitHub token for 5000 requests/hour rate limits
- **Static Site**: Generates a static HTML visualization and deploys to GitHub Pages
- **Zero Maintenance**: No local setup required after initial configuration

### 📋 **What It Does**
1. **Sets up Crystal** environment with latest compiler and shards
2. **Builds binaries** using `shards build --release`
3. **Collects project data** using improved rate limiting with GitHub token
4. **Generates static HTML** with interactive D3.js visualization
5. **Deploys to GitHub Pages** automatically

### ⚙️ **Configuration**
The workflow uses these environment variables:
- `GITHUB_TOKEN`: Automatic from GitHub Actions (5000 requests/hour)
- `GITHUB_USER`: Repository owner (auto-detected)
- `MAX_DEPTH`: 3 levels of dependency scanning
- `MAX_PROJECTS`: 500 maximum projects
- `RATE_LIMIT_DELAY`: 0.5 seconds between API calls

### 🌐 **Result**
- **Live visualization** at `https://<username>.github.io/rpu/`
- **Always fresh data** updated daily
- **Interactive features**: zoom, pan, tooltips, clickable nodes
- **Mobile responsive** design
- **Performance optimized** static site

### 📊 **Workflow Triggers**
The workflow runs automatically when:
- **Daily**: Every day at 2 AM UTC (8 PM EST, 5 PM PST)
- **Manual**: Click "Run workflow" in Actions tab
- **Code changes**: Push to main branch affecting source code
- **Workflow changes**: Updates to GitHub Actions files

### 🛠️ **Setup Required**
Just enable GitHub Pages in your repository:

1. Go to **Settings** → **Pages**
2. Select **GitHub Actions** as the source
3. **Save** - that's it!

The first run will take a few minutes, but subsequent daily updates will be much faster.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Run linting and tests
6. Submit a pull request

**Note**: Any changes to the codebase will automatically trigger a new deployment to GitHub Pages!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Technology Stack

- **Backend** - Crystal with Kemal web framework
- **Frontend** - D3.js for visualization, pico.css for styling
- **Data Collection** - GitHub API, Git
- **Build System** - Shards, Make

## Inspiration

This tool was created to help understand the relationships and scale of a Crystal developer's open source contributions at a glance. Perfect for:
- Portfolio showcasing
- Dependency analysis
- Project archaeology
- Community contribution tracking