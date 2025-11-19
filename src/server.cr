require "kemal"
require "json"
require "ecr"

# Project data structure (matches collector)
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

# Routes
get "/" do
  render "public/index.ecr"
end

get "/projects.json" do |env|
  if File.exists?("public/projects.json")
    send_file env, "public/projects.json"
  else
    env.response.status_code = 404
    {error: "Project data not found. Run 'crystal run src/collect_data.cr' first."}.to_json
  end
end

# Serve static files
get "/static/*" do |env|
  file_path = env.params.url["file"]
  send_file env, "public/#{file_path}"
end

# Start the server
Kemal.config.port = ENV["PORT"]?.try(&.to_i) || 3000
puts "🚀 Starting Crystal Projects Visualization Server"
puts "📊 Open http://localhost:#{Kemal.config.port} to view the visualization"
puts "🔄 Run 'crystal run src/collect_data.cr' to update project data"

Kemal.run