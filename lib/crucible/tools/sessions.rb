# frozen_string_literal: true

require 'mcp'
require 'json'

module Crucible
  module Tools
    # Session management tools: list_sessions, close_session
    module Sessions
      class << self
        def tools(sessions, _config)
          [
            list_sessions_tool(sessions),
            close_session_tool(sessions)
          ]
        end

        private

        def list_sessions_tool(sessions)
          MCP::Tool.define(
            name: 'list_sessions',
            description: 'List all active browser sessions',
            input_schema: {
              type: 'object',
              properties: {},
              required: []
            }
          ) do |**|
            session_list = sessions.list

            if session_list.empty?
              MCP::Tool::Response.new([{ type: 'text', text: 'No active sessions' }])
            else
              result = {
                count: session_list.size,
                sessions: session_list
              }
              MCP::Tool::Response.new([{ type: 'text', text: JSON.pretty_generate(result) }])
            end
          end
        end

        def close_session_tool(sessions)
          MCP::Tool.define(
            name: 'close_session',
            description: 'Close a browser session and free resources',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name to close'
                },
                all: {
                  type: 'boolean',
                  description: 'Close all sessions',
                  default: false
                }
              },
              required: []
            }
          ) do |session: nil, all: false, **|
            if all
              count = sessions.count
              sessions.close_all
              MCP::Tool::Response.new([{ type: 'text', text: "Closed #{count} session(s)" }])
            elsif session
              if sessions.close(session)
                MCP::Tool::Response.new([{ type: 'text', text: "Closed session: #{session}" }])
              else
                MCP::Tool::Response.new([{ type: 'text', text: "Session not found: #{session}" }], error: true)
              end
            else
              MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: 'Please specify a session name or use all: true to close all sessions'
                                      }], error: true)
            end
          end
        end
      end
    end
  end
end
