# frozen_string_literal: true

require_relative 'crucible/version'

# Crucible: MCP server for browser automation using Ferrum/Chrome
#
# Provides browser automation tools for AI agents via the Model Context Protocol.
# Supports multiple named sessions, navigation, screenshots, form interaction,
# JavaScript evaluation, cookie management, and PDF generation.
#
# @example Basic usage
#   Crucible.configure do |config|
#     config.headless = true
#     config.timeout = 30
#   end
#   Crucible.run
#
module Crucible
  class Error < StandardError; end
  class SessionNotFoundError < Error; end
  class ElementNotFoundError < Error; end
  class TimeoutError < Error; end
  class BrowserError < Error; end

  autoload :Configuration, 'crucible/configuration'
  autoload :Server, 'crucible/server'
  autoload :SessionManager, 'crucible/session_manager'
  autoload :Stealth, 'crucible/stealth'
  autoload :Tools, 'crucible/tools'

  class << self
    attr_writer :configuration

    # Returns the current configuration, initializing with defaults if needed
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the configuration for modification
    # @yield [Configuration] the configuration instance
    # @return [Configuration]
    def configure
      yield(configuration) if block_given?
      configuration
    end

    # Starts the MCP server with the given options
    # @param options [Hash] configuration overrides
    def run(**options)
      config = options.empty? ? configuration : configuration.merge(options)
      Server.new(config).run
    end

    # Resets configuration to defaults (mainly for testing)
    def reset!
      @configuration = nil
    end
  end
end
