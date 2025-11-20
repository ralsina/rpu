let projects = [];
let simulation;
let svg, g, link, node, label;
let showLabels = false;
let showExternal = true;

// Load and parse project data
fetch('projects.json')
    .then(response => response.json())
    .then(data => {
        projects = data;
        initVisualization();
    })
    .catch(error => {
        console.error('Error loading project data:', error);
        document.getElementById('graph').innerHTML =
            '<p style="text-align: center; padding: 50px;">Error loading project data. Please check back later.</p>';
    });

function initVisualization() {
    const container = d3.select('#graph');
    const width = container.node().getBoundingClientRect().width;
    const height = container.node().getBoundingClientRect().height;

    // Create SVG
    svg = container.append('svg')
        .attr('width', width)
        .attr('height', height);

    // Add zoom behavior
    const zoom = d3.zoom()
        .scaleExtent([0.1, 5])
        .on('zoom', (event) => {
            g.attr('transform', event.transform);
        });

    svg.call(zoom);

    g = svg.append('g');

    // Create force simulation
    simulation = d3.forceSimulation()
        .force('link', d3.forceLink().id(d => d.shard_name).distance(100))
        .force('charge', d3.forceManyBody().strength(-300))
        .force('center', d3.forceCenter(width / 2, height / 2))
        .force('collision', d3.forceCollide().radius(d => Math.sqrt(d.loc || 1000) + 5));

    // Process nodes and links
    const { nodes, links } = processGraphData(projects);

    // Create links
    link = g.append('g')
        .selectAll('line')
        .data(links)
        .enter().append('line')
        .attr('class', 'link')
        .attr('stroke-dasharray', d => d.source.external || d.target.external ? '5,5' : null);

    // Create nodes with different shapes
    node = g.append('g')
        .selectAll('.node')
        .data(nodes)
        .enter().append(d => {
            if (d.external) {
                // Create triangle for external dependencies
                return document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
            } else {
                // Create circle for regular projects and forks
                return document.createElementNS('http://www.w3.org/2000/svg', 'circle');
            }
        })
        .attr('class', d => d.fork ? 'node fork' : d.external ? 'node external' : 'node')
        .attr('fill', d => getNodeColor(d))
        .attr('stroke', '#fff')
        .attr('stroke-width', '2px')
        .on('click', (event, d) => {
            if (d.url && !d.url.startsWith('data:')) {
                window.open(d.url, '_blank');
            }
        })
        .on('mouseover', showTooltip)
        .on('mouseout', hideTooltip);

    // Set shape-specific attributes
    node.each(function(d) {
        const node = d3.select(this);
        if (d.external) {
            // Triangle for external dependencies
            const size = 8;
            const points = `0,${-size} ${-size},${size} ${size},${size}`;
            node.attr('points', points)
                .attr('stroke', '#4682b4')
                .attr('stroke-width', '2px');
        } else {
            // Circle for regular projects and forks
            const radius = Math.sqrt(Math.max(d.loc || 100, 100)) / 2;
            node.attr('r', radius);
            if (d.fork) {
                node.attr('stroke', '#ff6b35')
                    .attr('stroke-width', '3px');
            }
        }
    });

    // Create labels
    label = g.append('g')
        .selectAll('text')
        .data(nodes.filter(d => !d.external))
        .enter().append('text')
        .text(d => d.name)
        .style('font-size', '10px')
        .style('text-anchor', 'middle')
        .style('dy', '.35em')
        .style('pointer-events', 'none')
        .style('opacity', 0);

    // Start simulation
    simulation.nodes(nodes)
        .on('tick', ticked);

    simulation.force('link').links(links);

    // Update stats
    updateStats();
    updateLastUpdated();
}

function processGraphData(projects) {
    const nodes = [];
    const links = [];
    const nodeMap = new Map();

    // Add project nodes
    projects.forEach(project => {
        const node = {
            id: project.shard_name,
            name: project.name,
            shard_name: project.shard_name,
            loc: project.loc,
            description: project.description,
            url: project.url,
            fork: project.fork,
            external: project.external,
            last_modified: project.last_modified
        };
        nodes.push(node);
        nodeMap.set(project.shard_name, node);
    });

    // Add dependency links
    projects.forEach(project => {
        project.dependencies.forEach(dep => {
            const target = nodeMap.get(dep);
            if (target) {
                links.push({
                    source: project.shard_name,
                    target: dep,
                    value: 1
                });
            } else if (showExternal) {
                // Add external dependency node if it doesn't exist
                if (!nodeMap.has(dep)) {
                    const externalNode = {
                        id: dep,
                        name: dep,
                        shard_name: dep,
                        external: true,
                        loc: 0,
                        description: `External dependency: ${dep}`,
                        url: `https://github.com/search?q=${dep}+language%3ACrystal`
                    };
                    nodes.push(externalNode);
                    nodeMap.set(dep, externalNode);
                }
                links.push({
                    source: project.shard_name,
                    target: dep,
                    value: 1
                });
            }
        });
    });

    return { nodes, links };
}

function getNodeColor(node) {
    if (node.external) return '#87ceeb';

    if (!node.last_modified) return '#999';

    const now = new Date();
    const modified = new Date(node.last_modified);
    const daysDiff = (now - modified) / (1000 * 60 * 60 * 24);

    if (daysDiff < 30) return '#22c55e';      // Green - recent
    if (daysDiff < 90) return '#84cc16';      // Light green
    if (daysDiff < 180) return '#eab308';     // Yellow
    if (daysDiff < 365) return '#f97316';     // Orange
    return '#ef4444';                         // Red - old
}

function ticked() {
    link
        .attr('x1', d => d.source.x)
        .attr('y1', d => d.source.y)
        .attr('x2', d => d.target.x)
        .attr('y2', d => d.target.y);

    node.attr('transform', d => `translate(${d.x},${d.y})`);

    label
        .attr('x', d => d.x)
        .attr('y', d => d.y);
}

function showTooltip(event, d) {
    const tooltip = d3.select('#tooltip');
    tooltip.transition().duration(200).style('opacity', .9);
    tooltip.html(`
        <strong>${d.name}</strong><br/>
        ${d.description || 'No description'}<br/>
        ${d.loc ? `LOC: ${d.loc.toLocaleString()}<br/>` : ''}
        ${d.fork ? '🔄 Fork<br/>' : ''}
        ${d.external ? '📦 External dependency<br/>' : ''}
        ${d.last_modified ? `Modified: ${new Date(d.last_modified).toLocaleDateString()}<br/>` : ''}
        ${!d.external ? '<em>Click to open repository</em>' : ''}
    `)
    .style('left', (event.pageX + 10) + 'px')
    .style('top', (event.pageY - 28) + 'px');
}

function hideTooltip() {
    d3.select('#tooltip').transition().duration(500).style('opacity', 0);
}

function toggleLabels() {
    showLabels = !showLabels;
    label.style('opacity', showLabels ? 1 : 0);
}

function resetZoom() {
    svg.transition().duration(750).call(
        d3.zoom().transform,
        d3.zoomIdentity
    );
}

function toggleExternalDeps() {
    showExternal = !showExternal;
    initVisualization();
}

function updateStats() {
    const internalProjects = projects.filter(p => !p.external);
    const totalLOC = internalProjects.reduce((sum, p) => sum + (p.loc || 0), 0);
    const totalDeps = internalProjects.reduce((sum, p) => sum + p.dependencies.length, 0);

    document.getElementById('project-count').textContent = internalProjects.length.toLocaleString();
    document.getElementById('loc-count').textContent = Math.round(totalLOC / 1000) + 'k';
    document.getElementById('dep-count').textContent = totalDeps.toLocaleString();
}

function updateLastUpdated() {
    const now = new Date();
    document.getElementById('last-updated').textContent =
        `Last updated: ${now.toLocaleDateString()} at ${now.toLocaleTimeString()}`;
}

// Handle window resize
window.addEventListener('resize', () => {
    if (projects.length > 0) {
        d3.select('#graph').selectAll('*').remove();
        initVisualization();
    }
});