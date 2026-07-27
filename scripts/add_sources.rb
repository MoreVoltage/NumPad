#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Registers Swift sources with NumPad.xcodeproj targets.
#
# Usage:
#   ruby scripts/add_sources.rb <target>[,<target>...] <path> [<path>...]
#
# Paths are repo-relative. Directories are walked recursively for *.swift.
# Files already registered with a target are skipped, so re-running is safe.
# Group structure mirrors the on-disk folder hierarchy.

require 'xcodeproj'

TARGETS = { 'NumPad' => nil, 'Keyboard' => nil, 'NumPadTests' => nil, 'NumPadUITests' => nil }.freeze

target_names = (ARGV.shift || '').split(',').map(&:strip).reject(&:empty?)
paths = ARGV

abort "usage: add_sources.rb <target>[,<target>] <path>..." if target_names.empty? || paths.empty?

root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'NumPad.xcodeproj'))

targets = target_names.map do |name|
  unless TARGETS.key?(name)
    abort "unknown target #{name.inspect}; expected one of #{TARGETS.keys.join(', ')}"
  end
  project.targets.find { |t| t.name == name } or abort "target #{name.inspect} not found in project"
end

# Expand the requested paths into a concrete list of repo-relative Swift files.
sources = paths.flat_map do |path|
  absolute = File.expand_path(path, root)
  if File.directory?(absolute)
    Dir.glob(File.join(absolute, '**', '*.swift')).sort
  elsif File.file?(absolute)
    [absolute]
  else
    abort "path not found: #{path}"
  end
end.map { |absolute| absolute.sub("#{root}/", '') }.uniq

abort 'no Swift files matched' if sources.empty?

# Reuse an existing group for a directory when one is already mapped to it,
# otherwise create the chain so new files land beside their neighbours.
def group_for(project, relative_dir)
  return project.main_group if relative_dir == '.' || relative_dir.empty?

  relative_dir.split('/').reduce(project.main_group) do |parent, name|
    parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == name } ||
      parent.new_group(name, name)
  end
end

added = Hash.new { |h, k| h[k] = [] }
skipped = []

sources.each do |relative|
  group = group_for(project, File.dirname(relative))
  reference = group.files.find { |f| f.real_path.to_s == File.join(root, relative) }
  reference ||= begin
    ref = group.new_reference(File.join(root, relative))
    ref.source_tree = 'SOURCE_ROOT'
    ref.path = relative
    ref
  end

  targets.each do |target|
    already = target.source_build_phase.files_references.include?(reference)
    if already
      skipped << "#{relative} (#{target.name})"
    else
      target.add_file_references([reference])
      added[target.name] << relative
    end
  end
end

project.save

added.each do |target, files|
  puts "#{target}: added #{files.size}"
  files.each { |f| puts "  + #{f}" }
end
puts "skipped (already registered): #{skipped.size}" unless skipped.empty?
