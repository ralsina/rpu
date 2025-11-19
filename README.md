# Crystal Projects Visualization (RPU)

🔮 An interactive visualization tool for exploring Crystal project dependencies and metrics.

## Overview

This project creates a beautiful, interactive web visualization showing:
- **Project nodes** sized by Lines of Code (LOC)
- **Colors** representing recency of modifications (warmer = more recent)
- **Dependency connections** showing which projects use which
- **Interactive features** like zoom, tooltips, and clickable nodes

## Features

- 📊 **Automatic data collection** - Scans GitHub for Crystal projects with `shard.yml`
- 📈 **Dependency graphing** - Shows internal project dependencies
- 🎨 **Beautiful visualization** - Uses D3.js force-directed graph with pico.css styling
- 🔄 **Live updates** - Re-run data collection to get latest project information
- 📱 **Responsive design** - Works on desktop and mobile devices
- ⚡ **Fast** - Built with Crystal for performance

## Requirements

- [Crystal](https://crystal-lang.org/) (>= 1.0)
- [GitHub CLI](https://cli.github.com/) (gh) - for repository discovery
- [tokei](https://github.com/XAMPPRocky/tokei) - for LOC counting
- Git - for cloning repositories

## Quick Start

1. **Clone and setup:**
   ```bash
   git clone <this-repo>
   cd rpu
   make setup
   ```

2. **Collect project data:**
   ```bash
   make update
   ```
   This will:
   - Discover all Crystal repositories for your GitHub user
   - Clone them locally
   - Parse dependencies from `shard.yml`
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

To change the GitHub user being analyzed, edit `src/collect_data.cr`:

```crystal
GITHUB_USER = "your-username"
```

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
- **Node size** - Lines of Code for your projects (larger = more code), fixed size for external dependencies
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

1. **Repository Discovery** - Uses GitHub CLI to find repos with `shard.yml`
2. **Cloning** - Clones repositories to `projects/` directory
3. **Dependency Parsing** - Extracts Crystal dependencies from `shard.yml`
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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Run linting and tests
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Technology Stack

- **Backend** - Crystal with Kemal web framework
- **Frontend** - D3.js for visualization, pico.css for styling
- **Data Collection** - GitHub CLI, tokei, Git
- **Build System** - Shards, Make

## Inspiration

This tool was created to help understand the relationships and scale of a Crystal developer's open source contributions at a glance. Perfect for:
- Portfolio showcasing
- Dependency analysis
- Project archaeology
- Community contribution tracking