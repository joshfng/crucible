# frozen_string_literal: true

require 'mcp'

module Crucible
  module Tools
    # Navigation tools: navigate, wait_for, back, forward, refresh
    module Navigation
      class << self
        def tools(sessions, _config)
          [
            navigate_tool(sessions),
            wait_for_tool(sessions),
            back_tool(sessions),
            forward_tool(sessions),
            refresh_tool(sessions)
          ]
        end

        private

        def navigate_tool(sessions)
          MCP::Tool.define(
            name: 'navigate',
            description: "Navigate browser to a URL. Creates a new session if it doesn't exist.",
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name for managing multiple browsers',
                  default: 'default'
                },
                url: {
                  type: 'string',
                  description: 'URL to navigate to'
                }
              },
              required: ['url']
            }
          ) do |url:, session: 'default', **|
            page = sessions.page(session)
            page.go_to(url)

            MCP::Tool::Response.new(
              [{
                type: 'text',
                text: "Navigated to #{url} (session: #{session})"
              }]
            )
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Navigation failed: #{e.message}" }], error: true)
          end
        end

        def wait_for_tool(sessions)
          MCP::Tool.define(
            name: 'wait_for',
            description: 'Wait for an element to appear on the page',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                selector: {
                  type: 'string',
                  description: 'CSS selector to wait for'
                },
                timeout: {
                  type: 'number',
                  description: 'Maximum wait time in seconds',
                  default: 30
                }
              },
              required: ['selector']
            }
          ) do |selector:, session: 'default', timeout: 30, **|
            page = sessions.page(session)

            # Poll for element with timeout
            start_time = Time.now
            element = nil
            loop do
              element = page.at_css(selector)
              break if element

              if Time.now - start_time > timeout
                return MCP::Tool::Response.new([{ type: 'text', text: "Timeout waiting for: #{selector}" }],
                                               error: true)
              end

              sleep 0.1
            end

            MCP::Tool::Response.new([{ type: 'text', text: "Found element: #{selector}" }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Wait failed: #{e.message}" }], error: true)
          end
        end

        def back_tool(sessions)
          MCP::Tool.define(
            name: 'back',
            description: 'Navigate back in browser history',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                }
              },
              required: []
            }
          ) do |session: 'default', **|
            page = sessions.page(session)
            page.back

            MCP::Tool::Response.new([{ type: 'text', text: 'Navigated back' }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Back navigation failed: #{e.message}" }], error: true)
          end
        end

        def forward_tool(sessions)
          MCP::Tool.define(
            name: 'forward',
            description: 'Navigate forward in browser history',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                }
              },
              required: []
            }
          ) do |session: 'default', **|
            page = sessions.page(session)
            page.forward

            MCP::Tool::Response.new([{ type: 'text', text: 'Navigated forward' }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Forward navigation failed: #{e.message}" }], error: true)
          end
        end

        def refresh_tool(sessions)
          MCP::Tool.define(
            name: 'refresh',
            description: 'Refresh the current page',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                }
              },
              required: []
            }
          ) do |session: 'default', **|
            page = sessions.page(session)
            page.refresh

            MCP::Tool::Response.new([{ type: 'text', text: 'Page refreshed' }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Refresh failed: #{e.message}" }], error: true)
          end
        end
      end
    end
  end
end
