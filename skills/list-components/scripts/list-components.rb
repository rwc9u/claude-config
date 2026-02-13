#!/usr/bin/env ruby
# frozen_string_literal: true

# list-components.rb - Discover all Claude Code skills, commands, agents, hooks, MCP servers, and LSP servers
# Outputs a structured report with source attribution for each component

require "json"
require "pathname"
require "time"

CLAUDE_DIR = File.join(Dir.home, ".claude")
PLUGINS_DIR = File.join(CLAUDE_DIR, "plugins")
INSTALLED_PLUGINS_PATH = File.join(PLUGINS_DIR, "installed_plugins.json")
KNOWN_MARKETPLACES_PATH = File.join(PLUGINS_DIR, "known_marketplaces.json")
COMMANDS_DIR = File.join(CLAUDE_DIR, "commands")
SKILLS_DIR = File.join(CLAUDE_DIR, "skills")
AGENTS_DIR = File.join(CLAUDE_DIR, "agents")
HOOKS_DIR = File.join(CLAUDE_DIR, "hooks")

def load_json(path)
  return nil unless File.exist?(path)
  JSON.parse(File.read(path))
rescue JSON::ParserError
  nil
end

def resolve_symlink(path)
  File.symlink?(path) ? File.readlink(path) : nil
end

def extract_frontmatter(path)
  return {} unless File.exist?(path)

  content = File.read(path)
  match = content.match(/\A---\s*\n(.*?)\n---/m)
  return {} unless match

  frontmatter = {}
  match[1].each_line do |line|
    if line =~ /^(\w+):\s*(.+)/
      frontmatter[$1] = $2.strip
    end
  end
  frontmatter
end

def truncate(str, max = 120)
  return str if str.nil? || str.length <= max
  "#{str[0...max]}..."
end

def marketplace_source(marketplace_name, known_marketplaces)
  return "unknown" unless known_marketplaces

  info = known_marketplaces[marketplace_name]
  return "unknown" unless info

  source = info.dig("source", "source")
  case source
  when "github"
    repo = info.dig("source", "repo") || "unknown"
    "github:#{repo}"
  when "directory"
    dir_path = info.dig("source", "path") || "unknown"
    "local-directory:#{dir_path}"
  else
    source || "unknown"
  end
end

# --- Load registries ---

installed_plugins = load_json(INSTALLED_PLUGINS_PATH)
known_marketplaces = load_json(KNOWN_MARKETPLACES_PATH)

plugins = installed_plugins&.dig("plugins") || {}

# --- Counters for summary ---

counts = {
  marketplaces: known_marketplaces&.keys&.length || 0,
  plugins: plugins.keys.length,
  plugin_skills: 0,
  standalone_skills: 0,
  plugin_commands: 0,
  user_commands: 0,
  symlink_commands: 0,
  local_commands: 0,
  plugin_agents: 0,
  user_agents: 0,
  hook_plugins: 0,
  mcp_servers: 0,
  lsp_servers: 0
}

# --- Output ---

puts "============================================"
puts "  CLAUDE CODE COMPONENT INVENTORY"
puts "============================================"
puts
puts "Generated: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
puts

# =============================================
# SECTION 1: INSTALLED PLUGINS
# =============================================
puts "--------------------------------------------"
puts "  INSTALLED PLUGINS"
puts "--------------------------------------------"
puts

if plugins.empty?
  puts "  No installed plugins found."
  puts
else
  plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
    plugin_name, marketplace_name = plugin_key.split("@", 2)
    install = installations.first
    source = marketplace_source(marketplace_name, known_marketplaces)

    puts "  Plugin: #{plugin_name}"
    puts "    Marketplace: #{marketplace_name} (#{source})"
    puts "    Version: #{install["version"] || "unknown"}"
    puts "    Scope: #{install["scope"] || "unknown"}"
    puts "    Project: #{install["projectPath"]}" if install["projectPath"]
    puts "    Installed: #{install["installedAt"] || "unknown"}"
    puts "    Path: #{install["installPath"] || "unknown"}"
    puts
  end
end

# =============================================
# SECTION 2: SKILLS
# =============================================
puts "--------------------------------------------"
puts "  SKILLS"
puts "--------------------------------------------"
puts

puts "  -- Plugin Skills --"
puts

plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
  plugin_name, marketplace_name = plugin_key.split("@", 2)
  install_path = installations.first["installPath"]
  next unless install_path && Dir.exist?(install_path)

  skills_dir = File.join(install_path, "skills")
  next unless Dir.exist?(skills_dir)

  Dir.glob(File.join(skills_dir, "*")).select { |d| Dir.exist?(d) }.sort.each do |skill_dir|
    skill_md = File.join(skill_dir, "SKILL.md")
    next unless File.exist?(skill_md)

    counts[:plugin_skills] += 1
    skill_name = File.basename(skill_dir)
    fm = extract_frontmatter(skill_md)

    puts "  Skill: #{plugin_name}:#{skill_name}"
    puts "    Name: #{fm["name"]}" if fm["name"]
    puts "    Source: plugin (#{plugin_name}@#{marketplace_name})"
    puts "    Description: #{truncate(fm["description"])}" if fm["description"]

    resources = %w[scripts references examples assets]
      .select { |d| Dir.exist?(File.join(skill_dir, d)) }
      .map { |d| "#{d}/" }
    puts "    Resources: #{resources.join(" ")}" unless resources.empty?
    puts
  end
end

puts "  -- Standalone Skills (~/.claude/skills/) --"
puts

if Dir.exist?(SKILLS_DIR)
  standalone_skills = Dir.glob(File.join(SKILLS_DIR, "*")).select { |d| Dir.exist?(d) }.sort
  if standalone_skills.empty?
    puts "  (none found)"
    puts
  else
    standalone_skills.each do |entry|
      counts[:standalone_skills] += 1
      skill_name = File.basename(entry)
      symlink_target = resolve_symlink(entry)

      skill_md = File.join(entry, "SKILL.md")
      fm = File.exist?(skill_md) ? extract_frontmatter(skill_md) : {}

      puts "  Skill: #{skill_name}"
      puts "    Name: #{fm["name"]}" if fm["name"]
      if symlink_target
        puts "    Source: symlink -> #{symlink_target}"
      else
        puts "    Source: local (#{entry})"
      end
      puts "    Description: #{truncate(fm["description"])}" if fm["description"]
      puts
    end
  end
else
  puts "  (directory not found)"
  puts
end

# =============================================
# SECTION 3: COMMANDS
# =============================================
puts "--------------------------------------------"
puts "  COMMANDS"
puts "--------------------------------------------"
puts

puts "  -- Plugin Commands --"
puts

found_plugin_cmds = false
plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
  plugin_name, marketplace_name = plugin_key.split("@", 2)
  install_path = installations.first["installPath"]
  next unless install_path && Dir.exist?(install_path)

  commands_dir = File.join(install_path, "commands")
  next unless Dir.exist?(commands_dir)

  Dir.glob(File.join(commands_dir, "*.md")).sort.each do |cmd_file|
    found_plugin_cmds = true
    counts[:plugin_commands] += 1
    cmd_name = File.basename(cmd_file, ".md")
    fm = extract_frontmatter(cmd_file)

    puts "  Command: /#{plugin_name}:#{cmd_name}"
    puts "    Source: plugin (#{plugin_name}@#{marketplace_name})"
    puts "    Description: #{fm["description"]}" if fm["description"]
    puts
  end
end

unless found_plugin_cmds
  puts "  (none found)"
  puts
end

puts "  -- User Commands (~/.claude/commands/) --"
puts

if Dir.exist?(COMMANDS_DIR)
  Dir.glob(File.join(COMMANDS_DIR, "*.md")).sort.each do |cmd_file|
    counts[:user_commands] += 1
    cmd_name = File.basename(cmd_file, ".md")
    symlink_target = resolve_symlink(cmd_file)
    fm = extract_frontmatter(cmd_file)

    if symlink_target
      counts[:symlink_commands] += 1
    else
      counts[:local_commands] += 1
    end

    puts "  Command: /#{cmd_name}"
    if symlink_target
      puts "    Source: symlink -> #{symlink_target}"
    else
      puts "    Source: local file"
    end
    puts "    Description: #{fm["description"]}" if fm["description"]
    puts
  end
else
  puts "  (directory not found)"
  puts
end

# =============================================
# SECTION 4: AGENTS
# =============================================
puts "--------------------------------------------"
puts "  AGENTS"
puts "--------------------------------------------"
puts

puts "  -- Plugin Agents --"
puts

found_plugin_agents = false
plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
  plugin_name, marketplace_name = plugin_key.split("@", 2)
  install_path = installations.first["installPath"]
  next unless install_path && Dir.exist?(install_path)

  agents_dir = File.join(install_path, "agents")
  next unless Dir.exist?(agents_dir)

  Dir.glob(File.join(agents_dir, "*.md")).sort.each do |agent_file|
    found_plugin_agents = true
    counts[:plugin_agents] += 1
    agent_name = File.basename(agent_file, ".md")
    fm = extract_frontmatter(agent_file)

    puts "  Agent: #{plugin_name}:#{agent_name}"
    puts "    Source: plugin (#{plugin_name}@#{marketplace_name})"
    puts "    Description: #{truncate(fm["description"])}" if fm["description"]
    puts
  end
end

unless found_plugin_agents
  puts "  (none found)"
  puts
end

puts "  -- User Agents (~/.claude/agents/) --"
puts

if Dir.exist?(AGENTS_DIR)
  agent_files = Dir.glob(File.join(AGENTS_DIR, "*.md")).sort
  if agent_files.empty?
    puts "  (none found)"
    puts
  else
    agent_files.each do |agent_file|
      counts[:user_agents] += 1
      agent_name = File.basename(agent_file, ".md")
      symlink_target = resolve_symlink(agent_file)
      fm = extract_frontmatter(agent_file)

      puts "  Agent: #{agent_name}"
      if symlink_target
        puts "    Source: symlink -> #{symlink_target}"
      else
        puts "    Source: local file"
      end
      puts "    Description: #{truncate(fm["description"])}" if fm["description"]
      puts
    end
  end
else
  puts "  (directory not found)"
  puts
end

# =============================================
# SECTION 5: HOOKS
# =============================================
puts "--------------------------------------------"
puts "  HOOKS"
puts "--------------------------------------------"
puts

puts "  -- Plugin Hooks --"
puts

found_hooks = false
plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
  plugin_name, marketplace_name = plugin_key.split("@", 2)
  install_path = installations.first["installPath"]
  next unless install_path && Dir.exist?(install_path)

  # Find plugin.json
  plugin_json_path = File.join(install_path, ".claude-plugin", "plugin.json")
  plugin_json_path = File.join(install_path, "plugin.json") unless File.exist?(plugin_json_path)
  next unless File.exist?(plugin_json_path)

  plugin_json = load_json(plugin_json_path)
  next unless plugin_json

  hooks_path = plugin_json["hooks"]
  next if hooks_path.nil? || hooks_path.empty?

  hooks_file = File.join(install_path, hooks_path)
  next unless File.exist?(hooks_file)

  hooks_data = load_json(hooks_file)
  next unless hooks_data&.dig("hooks")

  found_hooks = true
  counts[:hook_plugins] += 1

  puts "  Plugin: #{plugin_name} (#{plugin_name}@#{marketplace_name})"
  puts "    Hooks file: #{hooks_path}"

  hooks_data["hooks"].each do |event, matchers|
    puts "    Event: #{event} (#{matchers.length} matcher(s))"
  end
  puts
end

unless found_hooks
  puts "  (none found)"
  puts
end

puts "  -- User Hooks (~/.claude/hooks/) --"
puts

if Dir.exist?(HOOKS_DIR)
  hooks_files = Dir.glob(File.join(HOOKS_DIR, "*.json")).sort
  if hooks_files.empty?
    puts "  (none found)"
    puts
  else
    hooks_files.each do |hooks_file|
      hooks_data = load_json(hooks_file)
      next unless hooks_data&.dig("hooks")

      puts "  File: #{File.basename(hooks_file)}"
      hooks_data["hooks"].each do |event, matchers|
        puts "    Event: #{event} (#{matchers.length} matcher(s))"
      end
      puts
    end
  end
else
  puts "  (directory not found)"
  puts
end

# =============================================
# SECTION 6: MCP SERVERS
# =============================================
puts "--------------------------------------------"
puts "  MCP SERVERS"
puts "--------------------------------------------"
puts

puts "  -- Plugin MCP Servers --"
puts

found_mcp = false
plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
  plugin_name, marketplace_name = plugin_key.split("@", 2)
  install_path = installations.first["installPath"]
  next unless install_path && Dir.exist?(install_path)

  mcp_file = File.join(install_path, ".mcp.json")
  next unless File.exist?(mcp_file)

  mcp_data = load_json(mcp_file)
  servers = mcp_data&.dig("mcpServers")
  next unless servers && !servers.empty?

  found_mcp = true
  counts[:mcp_servers] += servers.keys.length

  puts "  Plugin: #{plugin_name} (#{plugin_name}@#{marketplace_name})"
  servers.each do |name, config|
    server_type = config["type"] || "stdio"
    puts "    Server: #{name} (#{server_type})"
  end
  puts
end

unless found_mcp
  puts "  (none found)"
  puts
end

puts "  -- User MCP Servers (~/.claude/.mcp.json) --"
puts

user_mcp_path = File.join(CLAUDE_DIR, ".mcp.json")
if File.exist?(user_mcp_path)
  mcp_data = load_json(user_mcp_path)
  servers = mcp_data&.dig("mcpServers")
  if servers && !servers.empty?
    servers.each do |name, config|
      server_type = config["type"] || "stdio"
      puts "  Server: #{name} (#{server_type})"
    end
  else
    puts "  (none found)"
  end
else
  puts "  (file not found)"
end
puts

# =============================================
# SECTION 7: LSP SERVERS
# =============================================
puts "--------------------------------------------"
puts "  LSP SERVERS"
puts "--------------------------------------------"
puts

found_lsp = false
plugins.sort_by { |k, _| k }.each do |plugin_key, installations|
  plugin_name, marketplace_name = plugin_key.split("@", 2)
  install_path = installations.first["installPath"]
  next unless install_path && Dir.exist?(install_path)

  # Check .lsp.json first
  lsp_file = File.join(install_path, ".lsp.json")
  if File.exist?(lsp_file)
    lsp_data = load_json(lsp_file)
    if lsp_data && !lsp_data.empty?
      found_lsp = true
      counts[:lsp_servers] += lsp_data.keys.length

      puts "  Plugin: #{plugin_name} (#{plugin_name}@#{marketplace_name})"
      lsp_data.each do |lang, config|
        lsp_cmd = config["command"] || "unknown"
        puts "    LSP: #{lang} (#{lsp_cmd})"
      end
      puts
      next
    end
  end

  # Fallback: check plugin.json for lspServers
  plugin_json_path = File.join(install_path, ".claude-plugin", "plugin.json")
  plugin_json_path = File.join(install_path, "plugin.json") unless File.exist?(plugin_json_path)
  next unless File.exist?(plugin_json_path)

  plugin_json = load_json(plugin_json_path)
  lsp_servers = plugin_json&.dig("lspServers")
  next unless lsp_servers && !lsp_servers.empty?

  found_lsp = true
  counts[:lsp_servers] += lsp_servers.keys.length

  puts "  Plugin: #{plugin_name} (#{plugin_name}@#{marketplace_name})"
  lsp_servers.each do |lang, config|
    lsp_cmd = config["command"] || "unknown"
    puts "    LSP: #{lang} (#{lsp_cmd})"
  end
  puts
end

unless found_lsp
  puts "  (none found)"
  puts
end

# =============================================
# SECTION 8: SUMMARY
# =============================================
puts "--------------------------------------------"
puts "  SUMMARY"
puts "--------------------------------------------"
puts

total_skills = counts[:plugin_skills] + counts[:standalone_skills]
total_agents = counts[:plugin_agents] + counts[:user_agents]

puts "  Marketplaces: #{counts[:marketplaces]}"
puts "  Installed plugins: #{counts[:plugins]}"
puts "  Skills: #{total_skills} total (#{counts[:plugin_skills]} from plugins, #{counts[:standalone_skills]} standalone)"
puts "  User commands: #{counts[:user_commands]} total (#{counts[:symlink_commands]} symlinked, #{counts[:local_commands]} local files)"
puts "  Plugin commands: #{counts[:plugin_commands]}"
puts "  Agents: #{total_agents} total (#{counts[:plugin_agents]} from plugins, #{counts[:user_agents]} user)"
puts "  Hooks: #{counts[:hook_plugins]} plugin(s) with hooks"
puts "  MCP servers: #{counts[:mcp_servers]}"
puts "  LSP servers: #{counts[:lsp_servers]}"
puts
puts "============================================"
