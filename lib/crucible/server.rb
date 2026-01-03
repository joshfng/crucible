# frozen_string_literal: true

require 'mcp'

module Crucible
  # MCP Server for browser automation
  #
  # Provides browser automation tools via the Model Context Protocol.
  # Uses stdio transport for communication with AI agents.
  #
  # @example
  #   config = Crucible::Configuration.new(headless: true)
  #   server = Crucible::Server.new(config)
  #   server.run
  #
  class Server
    # @param config [Configuration, Hash] server configuration
    def initialize(config)
      @config = config.is_a?(Configuration) ? config : Configuration.new(config)
      @config.validate!
      @session_manager = SessionManager.new(@config)
      @running = false
    end

    # Starts the MCP server (blocking)
    def run
      @running = true
      setup_signal_handlers

      server = create_mcp_server
      transport = MCP::Server::Transports::StdioTransport.new(server)

      log(:info, "Crucible server starting (headless: #{@config.headless})")
      transport.open
    rescue Interrupt
      log(:info, 'Shutting down...')
    ensure
      shutdown
    end

    # Gracefully shuts down the server
    def shutdown
      return unless @running

      @running = false
      @session_manager.close_all
      log(:info, 'Server stopped')
    end

    private

    def create_mcp_server
      MCP::Server.new(
        name: 'crucible',
        version: VERSION,
        instructions: instructions_text,
        tools: Tools.all(@session_manager, @config)
      )
    end

    def instructions_text
      <<~INSTRUCTIONS
        Browser automation server powered by Ferrum and headless Chrome.

        ## Sessions
        Use the `session` parameter to manage multiple independent browser instances.
        Default session is "default". Sessions persist until explicitly closed.

        ## Common Workflows

        ### Basic Navigation
        1. navigate(url: "https://example.com")
        2. wait_for(selector: ".content")
        3. get_content(format: "text")

        ### Form Interaction
        1. navigate(url: "https://example.com/login")
        2. type(selector: "#email", text: "user@example.com")
        3. type(selector: "#password", text: "secret")
        4. click(selector: "button[type=submit]")

        ### Screenshots & PDFs
        - screenshot() - viewport screenshot
        - screenshot(full_page: true) - full page
        - screenshot(selector: ".element") - specific element
        - pdf(format: "A4", landscape: true)

        ### JavaScript Execution
        - evaluate(expression: "document.title")
        - evaluate(expression: "window.scrollTo(0, 0)")

        ## Session Management
        - list_sessions() - see all active sessions
        - close_session(session: "name") - close specific session
        - close_session(all: true) - close all sessions
      INSTRUCTIONS
    end

    def setup_signal_handlers
      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          # Can't call complex code (mutex) from trap context
          # Just raise Interrupt to let the main thread handle cleanup
          Thread.main.raise(Interrupt)
        end
      end
    end

    def log(level, message)
      return if should_suppress_log?(level)

      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      warn "[#{timestamp}] [#{level.upcase}] #{message}"
    end

    def should_suppress_log?(level)
      levels = %i[debug info warn error]
      current_level_index = levels.index(@config.error_level) || 2
      message_level_index = levels.index(level) || 0
      message_level_index < current_level_index
    end
  end
end
