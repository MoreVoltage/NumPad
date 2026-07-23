#!/usr/bin/env ruby
# Adds Swift source files to NumPad Xcode targets via the xcodeproj gem.
# Usage:
#   ruby scripts/add_xcode_files.rb --target NumPad --file NumPad/Libraries/Foo.swift
#   ruby scripts/add_xcode_files.rb --target NumPad,Keyboard --file NumPad/Libraries/Qwerty/Foo.swift
#   ruby scripts/add_xcode_files.rb --target NumPadTests --file NumPadTests/FooTests.swift

require 'xcodeproj'
require 'optparse'
require 'pathname'

options = { targets: [], files: [], project: 'NumPad.xcodeproj' }
OptionParser.new do |opts|
  opts.on('--project PATH') { |v| options[:project] = v }
  opts.on('--target NAMES') { |v| options[:targets] = v.split(',') }
  opts.on('--file PATH') { |v| options[:files] << v }
end.parse!

abort 'Need --target and --file' if options[:targets].empty? || options[:files].empty?

project = Xcodeproj::Project.open(options[:project])
root = Pathname.pwd

def find_or_create_group(project, file_path)
  parts = Pathname(file_path).each_filename.to_a
  top = parts.first
  group = project.main_group.children.find { |c| c.respond_to?(:display_name) && (c.display_name == top || c.path == top) }
  group ||= project.main_group.new_group(top, top)

  dirs = parts[1..-2] || []
  dirs.each do |dir|
    child = group.children.find { |c| c.respond_to?(:display_name) && (c.display_name == dir || c.path == dir) }
    unless child
      # Use only the directory name as path (relative to parent group path)
      child = group.new_group(dir, dir)
    end
    group = child
  end
  group
end

options[:files].each do |file_path|
  abs = root.join(file_path)
  abort "Missing file: #{file_path}" unless abs.exist?
  group = find_or_create_group(project, file_path)
  basename = File.basename(file_path)
  existing = group.files.find { |f| f.path == basename || (f.path && File.basename(f.path) == basename) }
  if existing
    ref = existing
    # Fix a previously doubled path if needed
    if existing.path && existing.path.include?('/')
      existing.path = basename
      puts "Fixed path for #{basename} -> #{basename}"
    end
  else
    # new_reference with only basename so it nests under the group's path
    ref = group.new_reference(basename)
    ref.source_tree = '<group>'
    puts "Created ref #{basename} in group #{group.display_name} (group path=#{group.path})"
  end

  options[:targets].each do |target_name|
    target = project.targets.find { |t| t.name == target_name }
    abort "Unknown target: #{target_name}" unless target
    next if target.source_build_phase.files_references.include?(ref)
    target.add_file_references([ref])
    puts "Added #{file_path} → #{target_name}"
  end
end

project.save
puts 'Saved project'
