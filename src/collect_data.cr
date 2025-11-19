#!/usr/bin/env crystal

require "json"
require "time"
require "file_utils"
require "ecr"
require "yaml"

# Configuration
GITHUB_USER = "ralsina"
PROJECTS_DIR = "projects"
DATA_FILE = "public/projects.json"

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
  property path : String
  property description : String?
  property url : String
  property loc : Int32 = 0
  property last_modified : Time?
  property dependencies : Array(String) = [] of String
  property external_dependencies : Array(String) = [] of String
  property fork : Bool = false
  property external : Bool = false

  def initialize(@name : String, @path : String, @url : String)
  end
end

# Main data collector class
class ProjectDataCollector
  def initialize
    @projects = [] of Project
    @external_deps_info = Hash(String, String).new
  end

  # Get all repositories for the user that have shard.yml
  def get_crystal_repos
    puts "#{Colors.blue("→")} Finding Crystal repositories for #{GITHUB_USER}..."

    repos = [] of String
    output = IO::Memory.new
    error = IO::Memory.new

    result = Process.run("gh", ["repo", "list", GITHUB_USER, "--limit", "200"],
                         output: output,
                         error: error)

    if result.success?
      output.to_s.each_line do |line|
        parts = line.split(/\t+/)
        repo = parts[0].strip
        repo_info = parts.size > 2 ? parts[2] : ""

        # Check if it has shard.yml
        check_output = IO::Memory.new
        check_error = IO::Memory.new
        check_result = Process.run("gh", ["api", "repos/#{repo}/contents/shard.yml"],
                                  output: check_output,
                                  error: check_error)
        if check_result.success?
          repos << repo
          # Check if it's a fork
          if repo_info.includes?("fork")
            print Colors.yellow("🔄")
          else
            print Colors.green("✓")
          end
        else
          print Colors.red("✗")
        end
      end
      puts
    else
      puts Colors.red("Failed to get repository list: #{error.to_s}")
      exit 1
    end

    repos
  end

  # Clone repositories if they don't exist
  def clone_repositories(repos)
    puts "#{Colors.blue("→")} Cloning repositories..."

    FileUtils.mkdir_p(PROJECTS_DIR) unless Dir.exists?(PROJECTS_DIR)

    Dir.cd(PROJECTS_DIR) do
      repos.each do |repo|
        dir_name = repo.split("/")[1]
        if Dir.exists?(dir_name)
          puts "#{Colors.yellow("→")} #{dir_name} already exists, skipping..."
          next
        end

        puts "#{Colors.blue("→")} Cloning #{repo}..."
        result = Process.run("git", ["clone", "git@github.com:#{repo}.git"],
                            output: Process::Redirect::Inherit,
                            error: Process::Redirect::Inherit)

        if result.success?
          puts Colors.green("✓ Cloned #{repo}")
        else
          puts Colors.red("✗ Failed to clone #{repo}")
        end
      end
    end
  end

  # Parse shard.yml to get dependencies
  def parse_dependencies(project_path) : Array(String)
    shard_file = File.join(project_path, "shard.yml")
    dependencies = [] of String

    if File.exists?(shard_file)
      begin
        shard = YAML.parse(File.read(shard_file))
        if shard["dependencies"]?
          shard["dependencies"].as_h.each_key do |dep|
            dependencies << dep.to_s
          end
        end
      rescue ex
        puts Colors.yellow("→ Warning: Failed to parse #{shard_file}: #{ex.message}")
      end
    end

    dependencies
  end

  # Get last modification date using git
  def get_last_modified(project_path) : Time?
    Dir.cd(project_path) do
      output = IO::Memory.new
      error = IO::Memory.new
      result = Process.run("git", ["log", "-1", "--format=%cI"],
                          output: output,
                          error: error)

      if result.success?
        time_str = output.to_s.strip
        Time.parse_rfc3339(time_str)
      else
        # Fallback to ISO format
        fallback = IO::Memory.new
        fallback_error = IO::Memory.new
        fallback_result = Process.run("git", ["log", "-1", "--format=%ci"],
                                     output: fallback,
                                     error: fallback_error)
        if fallback_result.success?
          time_str = fallback.to_s.strip
          # Parse format like "2025-11-19 16:02:15 -0300"
          Time.parse(time_str, "%Y-%m-%d %H:%M:%S %z", Time::Location::UTC)
        else
          nil
        end
      end
    end
  end

  # Calculate LOC using tokei
  def calculate_loc(project_path) : Int32
    output = IO::Memory.new
    error = IO::Memory.new
    result = Process.run("tokei", ["--output", "json", project_path],
                        output: output,
                        error: error)

    if result.success?
      json = JSON.parse(output.to_s)
      total_loc = 0

      # Look for Crystal specifically, but also count all if not found
      if json["Crystal"]?
        total_loc += json["Crystal"]["code"].as_i
      elsif json["Total"]?
        total_loc = json["Total"]["code"].as_i
      end

      total_loc
    else
      0
    end
  end

  # Collect data for all projects
  def collect_project_data(repos)
    puts "#{Colors.blue("→")} Collecting project data..."

    repos.each do |repo|
      repo_name = repo.split("/")[1]
      project_path = File.join(PROJECTS_DIR, repo_name)

      unless Dir.exists?(project_path)
        puts Colors.yellow("→ Skipping #{repo_name} (directory not found)")
        next
      end

      puts "#{Colors.blue("→")} Analyzing #{repo_name}..."

      # Get repo description
      api_output = IO::Memory.new
      api_error = IO::Memory.new
      api_result = Process.run("gh", ["api", "repos/#{repo}"],
                              output: api_output,
                              error: api_error)

      description = ""
      is_fork = false
      if api_result.success?
        json = JSON.parse(api_output.to_s)
        if json["description"]?
          desc = json["description"]
          description = desc.as_s? if !desc.nil?
        end
        description = "" if description.nil?

        # Check if it's a fork
        if json["fork"]?
          is_fork = json["fork"].as_bool
        end
      end

      project = Project.new(
        repo_name,
        project_path,
        "https://github.com/#{repo}",
      )
      project.description = description
      project.fork = is_fork
      project.dependencies = parse_dependencies(project_path)
      project.last_modified = get_last_modified(project_path)
      project.loc = calculate_loc(project_path)

      @projects << project
      puts Colors.green("✓ Analyzed #{repo_name} (#{project.loc} LOC, #{project.dependencies.size} deps)")
    end
  end

  # Cross-reference dependencies to find internal vs external
  def cross_reference_dependencies
    puts "#{Colors.blue("→")} Cross-referencing dependencies..."

    # Get original project names (before we add external ones)
    original_projects = @projects.dup
    project_names = original_projects.map(&.name).to_set

    original_projects.each do |project|
      internal_deps = [] of String
      external_project_deps = [] of String

      project.dependencies.each do |dep|
        # Check if any of our projects match this dependency
        matched = original_projects.find { |p| dep_matches(dep, p.name) }
        if matched
          internal_deps << matched.name
        else
          external_project_deps << dep
          # Extract URL from this project's shard.yml for this dependency
          extract_dependency_url(project.path, dep)
        end
      end

      # Update the project in @projects array
      project_to_update = @projects.find { |p| p.name == project.name }
      if project_to_update
        project_to_update.dependencies = internal_deps
        project_to_update.external_dependencies = external_project_deps
      end
    end

    puts "#{Colors.blue("→")} Found #{@external_deps_info.size} unique external dependencies"

    # Add external dependency nodes with exact URLs from shard.yml
    @external_deps_info.each do |dep_name, repo_url|
      external_project = Project.new(
        dep_name,
        "external",
        repo_url,
      )
      external_project.description = "External Crystal dependency"
      external_project.loc = 0
      external_project.dependencies = [] of String
      external_project.external_dependencies = [] of String
      external_project.fork = false
      external_project.external = true
      @projects << external_project
    end
  end

  # Extract the repository URL for a specific dependency from shard.yml
  private def extract_dependency_url(project_path, dep_name)
    shard_file = File.join(project_path, "shard.yml")

    if File.exists?(shard_file)
      begin
        shard_content = File.read(shard_file)

        # Look for the dependency section and extract the GitHub URL
        # Handle both formats:
        # github: user/repo
        # git: https://github.com/user/repo.git

        # Use regex to find the dependency section
        dep_section_regex = /#{Regex.escape(dep_name)}:\s*\n((?:\s+.*\n)*)/m
        match = shard_content.match(dep_section_regex)

        if match
          dep_content = match[1]

          # Look for github: or git: patterns
          github_match = dep_content.match(/github:\s*([^\/\s]+\/[^\/\s]+)/)
          if github_match
            repo_path = github_match[1]
            @external_deps_info[dep_name] = "https://github.com/#{repo_path}"
            return
          end

          git_match = dep_content.match(/git:\s*https:\/\/github\.com\/([^\/\s]+\/[^\/\s]+)\.git/)
          if git_match
            repo_path = git_match[1]
            @external_deps_info[dep_name] = "https://github.com/#{repo_path}"
            return
          end
        end

        # Fallback to common patterns if specific extraction fails
        common_patterns = [
          "crystal-lang/#{dep_name}",
          "luckyframework/#{dep_name}",
          "ivorg/#{dep_name}",
          "straight-shoota/#{dep_name}",
          "Sija/#{dep_name}",
        ]

        repo_path = common_patterns.find do |pattern|
          output = IO::Memory.new
          error = IO::Memory.new
          result = Process.run("gh", ["api", "repos/#{pattern}"],
                              output: output,
                              error: error)
          result.success?
        end

        if repo_path
          @external_deps_info[dep_name] = "https://github.com/#{repo_path}"
        end

      rescue ex
        puts Colors.yellow("→ Warning: Failed to parse #{shard_file}: #{ex.message}")
      end
    end
  end

  # Check if dependency name matches project name (considering variations)
  private def dep_matches(dep : String, project_name : String)
    return dep == project_name
    return dep == "#{project_name}.cr"
    return dep.gsub(/[^a-zA-Z0-9]/, "").downcase == project_name.gsub(/[^a-zA-Z0-9]/, "").downcase
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

    repos = get_crystal_repos
    puts Colors.green("✓ Found #{repos.size} Crystal repositories")

    clone_repositories(repos)
    collect_project_data(repos)
    cross_reference_dependencies

    puts Colors.green("✓ Collected data for #{@projects.size} projects")

    generate_json

    puts Colors.green("🎉 Data collection complete!")
    puts "#{Colors.blue("→")} Run 'shards install' && 'crystal src/server.cr' to start the visualization"
  end
end

# Run the collector
collector = ProjectDataCollector.new
collector.run