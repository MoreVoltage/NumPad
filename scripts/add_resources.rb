#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Registers bundle resources with NumPad.xcodeproj targets.
#
# Usage:
#   ruby scripts/add_resources.rb <target>[,<target>...] <path> [<path>...]
#
# Paths are repo-relative files. One PBX file reference is reused for every target and
# resource build-phase membership is idempotent.

require 'xcodeproj'

TARGETS = { 'NumPad' => nil, 'Keyboard' => nil, 'NumPadTests' => nil, 'NumPadUITests' => nil }.freeze

target_names = (ARGV.shift || '').split(',').map(&:strip).reject(&:empty?)
paths = ARGV

abort 'usage: add_resources.rb <target>[,<target>] <path>...' if target_names.empty? || paths.empty?

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'NumPad.xcodeproj'))

targets = target_names.map do |name|
  unless TARGETS.key?(name)
    abort "unknown target #{name.inspect}; expected one of #{TARGETS.keys.join(', ')}"
  end
  project.targets.find { |target| target.name == name } or abort "target #{name.inspect} not found in project"
end

resources = paths.map do |path|
  absolute = File.expand_path(path, root)
  abort "path not found: #{path}" unless File.file?(absolute)
  abort "path outside repository: #{path}" unless absolute.start_with?("#{root}/")

  absolute.sub("#{root}/", '')
end.uniq

def group_for(project, relative_dir)
  return project.main_group if relative_dir == '.' || relative_dir.empty?

  relative_dir.split('/').reduce(project.main_group) do |parent, name|
    parent.children.find do |child|
      child.is_a?(Xcodeproj::Project::Object::PBXGroup) && child.display_name == name
    end || parent.new_group(name, name)
  end
end

added = Hash.new { |hash, key| hash[key] = [] }
skipped = []

resources.each do |relative|
  absolute = File.join(root, relative)
  reference = project.files.find { |file| file.real_path.to_s == absolute }
  reference ||= begin
    group = group_for(project, File.dirname(relative))
    file = group.new_reference(absolute)
    file.source_tree = 'SOURCE_ROOT'
    file.path = relative
    file
  end

  targets.each do |target|
    if target.resources_build_phase.files_references.include?(reference)
      skipped << "#{relative} (#{target.name})"
    else
      target.resources_build_phase.add_file_reference(reference)
      added[target.name] << relative
    end
  end
end

project.save

added.each do |target, files|
  puts "#{target}: added #{files.size}"
  files.each { |file| puts "  + #{file}" }
end
puts "skipped (already registered): #{skipped.size}" unless skipped.empty?
