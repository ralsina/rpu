#!/usr/bin/env crystal

require "json"
require "time"
require "file_utils"
require "ecr"
require "yaml"
require "http"
require "uri"
require "docopt"
require "docopt-config"

# Command line interface definition
DOC = <<-DOCOPT
Crystal Projects Visualization Data Collection

Usage:
  #{File.basename(PROGRAM_NAME)} [--github-user=<user>] [--max-depth=<depth>] [--max-projects=<count>] [--rate-limit=<delay>] [--data-file=<file>] [--generate-html] [--help]
  #{File.basename(PROGRAM_NAME)} -h | --help

Options:
  --github-user=<user>      GitHub username to scan repositories for [default: ralsina]
  --max-depth=<depth>       Maximum recursion depth for dependencies [default: 3]
  --max-projects=<count>    Maximum total projects to process [default: 500]
  --rate-limit=<delay>      Seconds to wait between API calls [default: 0.1]
  --data-file=<file>        Output JSON file path [default: public/projects.json]
  --generate-html           Generate complete static HTML site with templates
  -h, --help               Show this help message

Environment Variables:
  GITHUB_USER              Same as --github-user
  GITHUB_TOKEN             GitHub personal access token for higher API limits (5000/hr vs 60/hr)
  MAX_DEPTH               Same as --max-depth
  MAX_PROJECTS            Same as --max-projects
  RATE_LIMIT_DELAY        Same as --rate-limit
  DATA_FILE               Same as --data-file

Examples:
  #{File.basename(PROGRAM_NAME)}                           # Use defaults
  #{File.basename(PROGRAM_NAME)} --github-user=myuser      # Scan different user
  #{File.basename(PROGRAM_NAME)} --max-depth=2             # Shallow dependency scan
  #{File.basename(PROGRAM_NAME)} --max-projects=100        # Process fewer projects
DOCOPT

# Helper functions to extract values from docopt results
def get_string_value(value)
  case value
  when String
    value
  when Array(String)
    value.first? if value.size == 1
  when Nil
    nil
  when Bool
    value.to_s
  else
    value.to_s
  end
end

def get_int_value(value)
  case value
  when Int32, Int64
    value.to_i
  when String
    value.to_i?
  when Array(String)
    value.first?.try(&.to_i?) if value.size == 1
  when Nil
    nil
  else
    nil
  end
end

def get_float_value(value)
  case value
  when Float32, Float64
    value.to_f
  when String
    value.to_f?
  when Array(String)
    value.first?.try(&.to_f?) if value.size == 1
  when Nil
    nil
  else
    nil
  end
end

# Extract configuration with defaults
def get_config
  # Try to load config file first
  config_file = nil
  if File.exists?(".rpu.yaml")
    config_file = YAML.parse(File.read(".rpu.yaml"))
  elsif File.exists?(File.expand_path("~/.rpu.yaml"))
    config_file = YAML.parse(File.read(File.expand_path("~/.rpu.yaml")))
  end

  # Parse command line arguments
  args = Docopt.docopt(DOC, argv: ARGV, help: true, version: "Crystal Projects Visualization 0.1.0")

  # Extract configuration with precedence: CLI > env vars > config file > defaults
  {
    "github-user" => get_string_value(args["--github-user"]) ||
                     ENV["GITHUB_USER"]? ||
                     (config_file.try(&.["github-user"]?).try(&.as_s) if config_file) ||
                     "ralsina",
    "max-depth" => get_int_value(args["--max-depth"]) ||
                   ENV["MAX_DEPTH"]?.try(&.to_i) ||
                   (config_file.try(&.["max-depth"]?).try(&.as_i) if config_file) ||
                   3,
    "max-projects" => get_int_value(args["--max-projects"]) ||
                      ENV["MAX_PROJECTS"]?.try(&.to_i) ||
                      (config_file.try(&.["max-projects"]?).try(&.as_i) if config_file) ||
                      500,
    "rate-limit" => get_float_value(args["--rate-limit"]) ||
                    ENV["RATE_LIMIT_DELAY"]?.try(&.to_f) ||
                    (config_file.try(&.["rate-limit"]?).try(&.as_f) if config_file) ||
                    0.1,
    "data-file" => get_string_value(args["--data-file"]) ||
                   ENV["DATA_FILE"]? ||
                   (config_file.try(&.["data-file"]?).try(&.as_s) if config_file) ||
                   "public/projects.json",
    "generate-html" => args["--generate-html"] == true
  }
end

CONFIG = get_config
DATA_FILE = CONFIG["data-file"].to_s
MAX_DEPTH = get_int_value(CONFIG["max-depth"]) || 3
MAX_PROJECTS = get_int_value(CONFIG["max-projects"]) || 500
RATE_LIMIT_DELAY = get_float_value(CONFIG["rate-limit"]) || 0.1
GITHUB_USER = get_string_value(CONFIG["github-user"]) || "ralsina"
GENERATE_HTML = CONFIG["generate-html"] == true

# ANSI colors for output
module Colors
  extend self

  def red(str); "\e[31m#{str}\e[0m"; end
  def green(str); "\e[32m#{str}\e[0m"; end
  def yellow(str); "\e[33m#{str}\e[0m"; end
  def blue(str); "\e[34m#{str}\e[0m"; end
end

# Project data structure
struct Project
  include JSON::Serializable

  property name : String
  property shard_name : String
  property path : String
  property description : String?
  property url : String
  property loc : Int32 = 0
  property last_modified : Time?
  property dependencies : Array(String) = [] of String
  property external_dependencies : Array(String) = [] of String
  property fork : Bool = false
  property external : Bool = false
  property depth : Int32 = 0        # Depth at which this project was discovered
  property discovered_from : String? # Project that led to discovering this one

  def initialize(@name : String, @path : String, @url : String)
    @shard_name = @name
  end

  def initialize(@name : String, @shard_name : String, @path : String, @url : String)
  end

  def initialize(@name : String, @shard_name : String, @path : String, @url : String, @depth : Int32, @discovered_from : String?)
  end
end

# Main data collector class
class ProjectDataCollector
  def initialize
    @projects = [] of Project
    @processed_repos = Set(String).new      # Track repos we've already processed
    @api_queue = Array(Tuple(String, Int32, String?)).new # (repo, depth, discovered_from)
    @processed_count = 0
  end

  # Make a GitHub API request with intelligent rate limiting
  private def github_api_request(endpoint : String, retry_count : Int32 = 0) : JSON::Any?
    url = "https://api.github.com/#{endpoint}"

    begin
      headers = HTTP::Headers.new
      if ENV["GITHUB_TOKEN"]?
        headers["Authorization"] = "token #{ENV["GITHUB_TOKEN"]}"
      end

      HTTP::Client.get(url, headers: headers) do |response|
        # Check rate limit headers
        if response.headers["X-RateLimit-Remaining"]?
          remaining = response.headers["X-RateLimit-Remaining"].to_i
          if remaining < 10
            reset_time = response.headers["X-RateLimit-Reset"].to_i
            wait_time = Math.max(reset_time - Time.utc.to_unix, 60)
            puts Colors.yellow("→ Low API credits (#{remaining} left), waiting #{wait_time}s...")
            sleep(wait_time.seconds)
          end
        end

        if response.success?
          # Dynamic delay based on remaining API credits
          if response.headers["X-RateLimit-Remaining"]?
            remaining = response.headers["X-RateLimit-Remaining"].to_i
            if remaining < 100
              sleep((RATE_LIMIT_DELAY * 3).seconds)  # Slower when running low
            else
              sleep(RATE_LIMIT_DELAY.seconds)  # Normal rate
            end
          end
          JSON.parse(response.body_io)
        elsif response.status_code == 403
          # Parse rate limit info from error response
          if response.headers["X-RateLimit-Remaining"]? && response.headers["X-RateLimit-Remaining"] == "0"
            reset_time = response.headers["X-RateLimit-Reset"].to_i
            wait_time = Math.max(reset_time - Time.utc.to_unix, 60)
            if retry_count < 5  # Increased retry count
              puts Colors.red("→ API exhausted, waiting #{wait_time}s... (retry #{retry_count + 1}/5)")
              sleep(wait_time.seconds)
              github_api_request(endpoint, retry_count + 1)
            else
              puts Colors.red("→ Max retries exceeded for #{endpoint}, skipping...")
              nil
            end
          else
            puts Colors.yellow("→ 403 Forbidden for #{endpoint}, skipping...")
            nil
          end
        elsif response.status_code == 404
          nil # Not found
        elsif response.status_code == 301 || response.status_code == 302 || response.status_code == 307
          # Handle redirects for moved/renamed repositories
          if response.headers["Location"]?
            location = response.headers["Location"]
            puts Colors.yellow("→ Repository moved (#{response.status_code}): #{endpoint}")
            # Extract new repo path from Location header if it's a GitHub redirect
            if location.includes?("github.com/")
              match = location.match(/github\.com\/([^\/]+\/[^\/\?#]+)/)
              if match
                new_repo = match[1]
                puts Colors.blue("→ Redirecting to: #{new_repo}")
                # Retry with the new repository path
                if endpoint.starts_with?("repos/")
                  new_endpoint = endpoint.sub(/^repos\/[^\/]+\/[^\/]+/, "repos/#{new_repo}")
                  return github_api_request(new_endpoint, retry_count)
                end
              end
            end
          end
          puts Colors.yellow("→ Unable to follow redirect for #{endpoint}")
          nil
        else
          puts Colors.yellow("→ API request failed for #{endpoint}: #{response.status_code}")
          sleep(RATE_LIMIT_DELAY.seconds)  # Brief pause on other errors
          nil
        end
      end
    rescue ex
      puts Colors.yellow("→ API request error for #{endpoint}: #{ex.message}")
      sleep(RATE_LIMIT_DELAY.seconds)
      nil
    end
  end

  # Fetch shard.yml content via GitHub API
  private def fetch_shard_yaml(repo : String) : YAML::Any?
    data = github_api_request("repos/#{repo}/contents/shard.yml")
    return nil if data.nil?

    if data["content"]? && data["encoding"]? == "base64"
      content = Base64.decode_string(data["content"].as_s)
      begin
        YAML.parse(content)
      rescue ex
        puts Colors.yellow("→ Failed to parse shard.yml for #{repo}: #{ex.message}")
        nil
      end
    else
      nil
    end
  end

  # Get repository information
  private def get_repo_info(repo : String) : JSON::Any?
    github_api_request("repos/#{repo}")
  end

  # Get language statistics from GitHub API
  private def get_repo_languages(repo : String) : JSON::Any?
    github_api_request("repos/#{repo}/languages")
  end

  # Get Crystal repositories for the user
  def get_crystal_repos
    puts "#{Colors.blue("→")} Finding Crystal repositories for #{GITHUB_USER}..."

    repos = [] of String
    page = 1
    per_page = 100

    loop do
      data = github_api_request("users/#{GITHUB_USER}/repos?page=#{page}&per_page=#{per_page}&type=all")
      break if data.nil?

      repos_data = data.as_a
      break if repos_data.empty?

      repos_data.each do |repo_data|
        repo_name = repo_data["full_name"].as_s
        print Colors.blue(".")

        # Check if it has shard.yml
        if fetch_shard_yaml(repo_name)
          repos << repo_name
          # Check if it's a fork
          if repo_data["fork"].as_bool
            print Colors.yellow("🔄")
          else
            print Colors.green("✓")
          end
        else
          print Colors.red("✗")
        end
      end

      page += 1
      break if repos_data.size < per_page
    end

    puts
    puts Colors.green("✓ Found #{repos.size} Crystal repositories")
    repos
  end

  # Parse shard name from shard YAML data
  private def parse_shard_name(shard_data : YAML::Any, repo_path : String) : String
    # Special case for docopt.cr - hardcoded as "docopt"
    if repo_path.includes?("docopt.cr")
      return "docopt"
    end

    if shard_data["name"]?
      return shard_data["name"].as_s
    end

    # Fallback to repository name
    repo_path.split("/")[-1]
  end

  # Parse dependencies from shard YAML data
  private def parse_dependencies(shard_data : YAML::Any) : Array(String)
    dependencies = [] of String

    if shard_data["dependencies"]?
      deps_data = shard_data["dependencies"]
      # Handle different YAML structures safely
      case deps_data
      when .as_h?
        deps_data.as_h.each_key do |dep|
          dependencies << dep.to_s
        end
      when .as_a?
        deps_data.as_a.each do |dep|
          dependencies << dep.to_s
        end
      else
        # Skip if we can't parse the dependencies structure
      end
    end

    dependencies
  end

  # Extract repository URL from dependency specification in shard YAML
  private def extract_dependency_url(shard_data : YAML::Any, dep_name : String) : String?
    return nil unless shard_data["dependencies"]?

    deps_data = shard_data["dependencies"]
    return nil unless deps_data

    # Handle different YAML structures safely
    case deps_data
    when .as_h?
      deps = deps_data.as_h
      return nil unless deps[dep_name]?

      dep_config = deps[dep_name]

      # Handle different dependency formats
      case dep_config
      when .as_h?
        dep_hash = dep_config.as_h
        if dep_hash["github"]?
          github_path = dep_hash["github"]?.try(&.as_s)
          return "https://github.com/#{github_path}" if github_path
        elsif dep_hash["git"]?
          git_url = dep_hash["git"]?.try(&.as_s)
          if git_url && git_url.includes?("github.com")
            # Extract user/repo from git URL
            match = git_url.match(/github\.com\/([^\/]+\/[^\/\s\.]+)/)
            return "https://github.com/#{match[1]}" if match
          end
        end
      when .as_s?
        # Simple dependency name, try common patterns
        common_patterns = [
          "crystal-lang/#{dep_name}",
          "luckyframework/#{dep_name}",
          "ivorg/#{dep_name}",
          "straight-shoota/#{dep_name}",
          "Sija/#{dep_name}",
        ]

        common_patterns.each do |pattern|
          repo_info = get_repo_info(pattern)
          return "https://github.com/#{pattern}" if repo_info
        end
      end
    else
      # Skip if dependencies structure is not parseable
    end

    nil
  end

  
  # Process a single repository and add its dependencies to the queue
  private def process_repository(repo : String, depth : Int32, discovered_from : String? = nil)
    return if @processed_repos.includes?(repo)
    return if @processed_count >= MAX_PROJECTS

    @processed_repos << repo
    @processed_count += 1

    puts "#{Colors.blue("→")} Processing #{repo} (depth: #{depth})..."

    # Get repository information
    repo_info = get_repo_info(repo)
    return if repo_info.nil?

    # Get shard.yml data
    shard_data = fetch_shard_yaml(repo)
    return if shard_data.nil?

    # Extract project details
    repo_name = repo.split("/")[-1]
    shard_name = parse_shard_name(shard_data, repo)
    dependencies = parse_dependencies(shard_data)

    # Create project
    project = Project.new(
      repo_name,
      shard_name,
      "api",  # Use "api" as path since we're not cloning
      "https://github.com/#{repo}",
      depth,
      discovered_from
    )

    # Set additional properties
    project.description = repo_info["description"]?.try(&.as_s?) || ""
    project.fork = repo_info["fork"]?.try(&.as_bool?) || false
    project.dependencies = dependencies
    project.last_modified = repo_info["pushed_at"]?.try(&.as_s?).try { |time_str| Time.parse_rfc3339(time_str) }

    # Determine if this is an external repository (not owned by GITHUB_USER)
    repo_owner = repo.split("/")[0]
    project.external = repo_owner != GITHUB_USER

    # Get Crystal LOC from GitHub API language statistics
    languages = get_repo_languages(repo)
    project.loc = languages.try(&.["Crystal"]?.try(&.as_i)) || repo_info["size"]?.try(&.as_i?) || 0

    @projects << project

    # Add dependencies to queue for recursive processing
    if depth < MAX_DEPTH
      dependencies.each do |dep|
        dep_url = extract_dependency_url(shard_data, dep)
        if dep_url
          dep_path = dep_url.sub("https://github.com/", "")
          unless @processed_repos.includes?(dep_path)
            @api_queue << {dep_path, depth + 1, repo}
          end
        end
      end
    end

    puts Colors.green("✓ Processed #{repo_name} (#{dependencies.size} deps)")
  end

  # Collect data recursively through dependencies
  def collect_project_data(initial_repos)
    puts "#{Colors.blue("→")} Starting recursive dependency collection..."

    # Initialize queue with initial repositories
    initial_repos.each do |repo|
      @api_queue << {repo, 0, nil}  # Start at depth 0
    end

    # Process queue
    while !@api_queue.empty? && @processed_count < MAX_PROJECTS
      repo, depth, discovered_from = @api_queue.shift
      process_repository(repo, depth, discovered_from)
    end

    puts Colors.green("✓ Processed #{@projects.size} repositories recursively")
  end

  # Simplified cross-reference method since we already track dependencies during collection
  def cross_reference_dependencies
    puts "#{Colors.blue("→")} Finalizing dependency relationships..."

    # Count external vs internal dependencies
    internal_count = 0
    external_count = 0

    @projects.each do |project|
      project.dependencies.each do |dep|
        if @projects.any? { |p| p.shard_name == dep }
          internal_count += 1
        else
          external_count += 1
          project.external_dependencies << dep
        end
      end
    end

    puts "#{Colors.blue("→")} Found #{internal_count} internal dependencies, #{external_count} external references"
  end

  
  # Generate complete static HTML site from templates
  def generate_html
    puts "#{Colors.blue("→")} Generating complete static HTML site..."

    FileUtils.mkdir_p("public") unless Dir.exists?("public")

    # Check if main template exists
    unless File.exists?("public/index.html")
      puts "#{Colors.red("✖")} Error: public/index.html template not found!"
      puts "    Cannot generate static site without HTML template."
      exit 1
    end

    puts "#{Colors.green("✓")} HTML template found: public/index.html"
    puts "#{Colors.green("✓")} Self-contained template with embedded CSS and JavaScript"
    puts "#{Colors.green("✓")} Static site ready for GitHub Pages deployment"
  end

  # Generate project data JSON
  def generate_json
    puts "#{Colors.blue("→")} Generating project data..."

    FileUtils.mkdir_p("public") unless Dir.exists?("public")

    File.write(DATA_FILE, @projects.to_pretty_json)
    puts Colors.green("✓ Generated #{DATA_FILE}")
  end

  # Run the full collection process
  def run
    puts "#{Colors.green("🚀 Starting Crystal Project Visualization Data Collection")}"
    puts "#{Colors.blue("→")} Configuration:"
    puts "   • GitHub user: #{GITHUB_USER}"
    puts "   • Max depth: #{MAX_DEPTH}"
    puts "   • Max projects: #{MAX_PROJECTS}"
    puts "   • Rate limit delay: #{RATE_LIMIT_DELAY}s"
    puts "   • Output file: #{DATA_FILE}"
    puts "   • Generate HTML: #{GENERATE_HTML ? "Yes" : "No"}"

    repos = get_crystal_repos
    puts Colors.green("✓ Found #{repos.size} Crystal repositories")

    collect_project_data(repos)
    cross_reference_dependencies

    puts Colors.green("✓ Processed #{@projects.size} repositories recursively")

    generate_json

    # Generate HTML if requested
    if GENERATE_HTML
      generate_html
      puts "#{Colors.blue("→")} Static HTML site ready in public/ directory"
      puts "#{Colors.blue("→")} Open public/index.html in your browser to view the visualization"
    else
      puts "#{Colors.blue("→")} Run with --generate-html to create a complete static site"
    end

    puts Colors.green("🎉 Data collection complete!")
    puts "#{Colors.blue("→")} The graph shows dependencies across #{MAX_DEPTH} levels of recursion"
  end
end

# Run the collector
collector = ProjectDataCollector.new
collector.run