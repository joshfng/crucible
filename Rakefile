# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Run the MCP server'
task :server do
  exec 'ruby', '-I', 'lib', 'exe/crucible'
end

desc 'Open an interactive console'
task :console do
  require 'irb'
  require_relative 'lib/crucible'
  ARGV.clear
  IRB.start(__FILE__)
end
