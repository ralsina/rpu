# Crystal Projects Visualization (RPU)

🔮 **Fork and Deploy Your Own Crystal Project Visualization in Minutes**

A Crystal tool that creates beautiful, interactive visualizations of Crystal project dependencies and automatically deploys them to GitHub Pages.

## ✨ **What It Does**

- **Discovers Projects**: Automatically finds all Crystal repositories with `shard.yml` using GitHub API
- **Analyzes Dependencies**: Maps internal and external Crystal dependencies across your projects
- **Creates Visualizations**: Generates interactive D3.js force-directed graphs showing project relationships
- **Auto-Deploys**: Builds and deploys a static site to GitHub Pages automatically
- **Updates Daily**: Fresh data every day with zero maintenance

## 🚀 **Quick Start - Fork and Deploy**

### 1. Fork This Repository
Click the "Fork" button at the top of this page to create your own copy.

### 2. Enable GitHub Pages
1. Go to your forked repository's **Settings**
2. Navigate to **Pages**
3. Under "Build and deployment", select **GitHub Actions** as the source
4. **Save**

### 3. Wait for Initial Build
The GitHub Actions workflow will automatically:
- Detect your GitHub username
- Collect your Crystal project data
- Build a static visualization
- Deploy to GitHub Pages

**❗ If GitHub Actions fails**, make sure you've enabled GitHub Pages correctly in step 2. The workflow requires GitHub Pages to be enabled with "GitHub Actions" as the source.

That's it! Your visualization will be live at `https://<your-username>.github.io/rpu/`

## 🌟 **Features**

### **Interactive Visualization**
- **Click nodes** - Focus on node and highlight connected dependencies (subnet visualization)
- **Hover tooltips** - Shows LOC, description, fork status, last modified date
- **Zoom/Pan** - Mouse wheel and drag navigation
- **Reset Zoom** - Reset view and clear selection
- **Labels** - Project names are shown by default for better readability

### **Visual Encoding**
- **Node size** - Lines of Crystal code (scaled between min/max for better visibility)
  - Regular projects: Sized based on LOC (12-30 units)
  - Forks and external dependencies: Fixed minimum size
- **Node color** - Activity level:
  - 🟢 Green: Modified within last month (actively maintained)
  - 🟡 Light green: Modified within 3 months (recently active)
  - 🟠 Yellow: Modified within 6 months (moderately active)
  - 🔶 Orange: Modified within 1 year (inactive)
  - 🔴 Red: Modified over 1 year ago (stale)
  - ⚫ Gray: Unknown last modified date
- **Node shapes**:
  - 🟢 Circles: Your original Crystal projects
  - 🔄 Hexagons: Forked projects (orange border)
  - 🔵 Pentagons: External Crystal dependencies
- **Lines with arrows**:
  - Solid: Internal dependencies between your projects
  - Dashed: External dependencies to third-party libraries
  - Arrow direction: Shows dependency flow

### **Subnet Highlighting**
When you click on any node:
- **Selected node** remains fully visible
- **Connected nodes** (dependencies) are highlighted
- **Unrelated nodes** are dimmed for clarity
- **Click again** or **click background** to deselect

### **Smart Data Collection**
- **GitHub API Integration**: Uses GitHub's native APIs for accurate data
- **Rate Limit Handling**: Intelligent API rate limiting with automatic retries
- **Dependency Scanning**: Recursive dependency analysis up to 3 levels deep
- **External Dependencies**: Automatically discovers and maps Crystal shard dependencies

## ⚙️ **How It Works**

### **GitHub Actions Workflow**
The `.github/workflows/update-and-deploy.yml` file automatically:

1. **Triggers**:
   - Daily at 2 AM UTC (8 PM EST, 5 PM PST)
   - Manual trigger from Actions tab
   - On code changes

2. **Data Collection**:
   - Uses repository's GitHub token (5000 requests/hour rate limit)
   - Scans up to 500 projects with 3 levels of dependency depth
   - Intelligent rate limiting to avoid API exhaustion

3. **Static Site Generation**:
   - Creates responsive HTML with D3.js visualization
   - Mobile-friendly design
   - Performance optimized

4. **Deployment**:
   - Automatic deployment to GitHub Pages
   - Zero hosting cost
   - Custom domain support

### **Configuration**
The workflow automatically adapts to your repository:
- **GitHub User**: Detected from repository owner
- **Rate Limits**: Uses GitHub Actions token for 5000 requests/hour
- **Scope**: Scans your public Crystal repositories
- **Depth**: 3 levels of dependency recursion
- **Projects**: Up to 500 projects total

## 🛠️ **Local Development**

For testing or customizing the data collection:

```bash
# Clone your fork
git clone https://github.com/<your-username>/rpu.git
cd rpu

# Install dependencies
make setup

# Build complete static site (recommended)
make build-static ARGS='--github-user=<your-username> --max-projects=10 --max-depth=1'

# Serve locally for development
make serve
# Open http://localhost:8000 in your browser

# Or just collect data (advanced usage)
make collect ARGS='--github-user=<your-username>'
```

### **Template-Based Architecture**

The visualization uses a template-based system:

- **`public/index.html`** - Main HTML template with embedded CSS and JavaScript
- **`public/style.css`** - Standalone CSS (optional, for development)
- **`public/visualization.js`** - Standalone JavaScript (optional, for development)
- **Self-contained deployment** - All CSS/JS embedded in final HTML for GitHub Pages

### **Troubleshooting**

**GitHub Actions Failing:**
- Make sure GitHub Pages is enabled with "GitHub Actions" as the source
- Check that your fork has proper GitHub Actions permissions enabled
- View the Actions tab in your repository for detailed error logs

**Local Development Issues:**
- **Browser cache**: If you see JavaScript errors, try `Ctrl+F5` (hard refresh) to clear cache
- **Missing dependencies**: Run `make setup` to install Crystal shards
- **Build errors**: Ensure Crystal is installed and run `make build`

**Visualization Issues:**
- **Node highlighting not working**: Clear browser cache with `Ctrl+F5`
- **Labels missing**: Check browser console for JavaScript errors
- **Arrow heads not visible**: Zoom in to see dependency arrows more clearly

### **Environment Variables**
Override defaults by setting environment variables:

```bash
GITHUB_USER=<username>          # GitHub user to scan
MAX_DEPTH=3                    # Dependency recursion depth
MAX_PROJECTS=500               # Maximum projects to process
RATE_LIMIT_DELAY=0.5           # Seconds between API calls
DATA_FILE=public/projects.json # Output file path
```

### **Forking for Others**
Anyone can fork your repository and get their own visualization:
1. Fork your repo
2. Enable GitHub Pages
3. Works automatically with their GitHub account

## 📊 **Example Use Cases**

- **Portfolio Showcase**: Display your Crystal open source contributions
- **Team Analytics**: Visualize team's Crystal project ecosystem
- **Dependency Analysis**: Understand project interdependencies
- **Community Mapping**: Explore Crystal ecosystem connections
- **Project Archaeology**: Discover old projects and activity patterns

## 🔄 **Automation**

The visualization updates automatically:
- **Daily**: Fresh data every morning
- **On Changes**: Code updates trigger new deployments
- **Manual**: Trigger from GitHub Actions tab anytime

No manual maintenance required after initial setup!

## 📁 **Project Structure**

```
rpu/
├── src/
│   └── collect_data.cr     # Data collection and dependency analysis
├── .github/workflows/
│   └── update-and-deploy.yml  # Automated CI/CD pipeline
├── public/                  # Generated static site (auto-created)
├── shard.yml              # Crystal dependencies
├── Makefile               # Development utilities
└── README.md              # This file
```

## 🤝 **Contributing**

Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `make test && make lint`
5. Submit a pull request

**Note**: Your changes will automatically deploy to your fork's GitHub Pages!

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 **Technology Stack**

- **Backend**: Crystal with GitHub API integration
- **Visualization**: D3.js force-directed graphs
- **Deployment**: GitHub Actions and GitHub Pages
- **Styling**: Pico.css for clean, responsive design
- **Data**: JSON with dependency graphs

---

**Ready to visualize your Crystal projects?** Fork this repository and enable GitHub Pages to get started! 🚀