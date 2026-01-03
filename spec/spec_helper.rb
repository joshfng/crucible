# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  enable_coverage :branch
  minimum_coverage 50 # Lower for now until more coverage added
end

require 'crucible'
require 'mcp'
require 'ferrum' # Load real Ferrum for error classes

# Helper to call MCP tools in tests
module ToolTestHelper
  def call_tool(tool, **args)
    tool.call(**args)
  end
end

RSpec.configure do |config|
  config.include ToolTestHelper

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed

  # Reset configuration between tests
  config.before do
    Crucible.reset!
  end
end
