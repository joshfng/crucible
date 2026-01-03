# frozen_string_literal: true

module Crucible
  module Tools
    # MCP tools for stealth mode management
    module Stealth
      VALID_PROFILES = %w[minimal moderate maximum].freeze

      class << self
        # Returns all stealth tools
        # @param sessions [SessionManager]
        # @param config [Configuration]
        # @return [Array<MCP::Tool>]
        def tools(sessions, config)
          [
            enable_stealth_tool(sessions, config),
            disable_stealth_tool(sessions),
            get_stealth_status_tool(sessions),
            set_stealth_profile_tool(sessions, config)
          ]
        end

        private

        # Tool: Enable stealth mode for a session
        def enable_stealth_tool(sessions, _config)
          MCP::Tool.define(
            name: 'enable_stealth',
            description: 'Enable stealth mode for a browser session. Stealth mode applies various ' \
                         'evasion techniques to make the browser appear as a regular user browser ' \
                         'to bot detection systems.',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                profile: {
                  type: 'string',
                  enum: VALID_PROFILES,
                  description: 'Stealth profile: minimal (basic evasions), moderate (common evasions), ' \
                               'or maximum (all evasions for strictest detection)'
                }
              },
              required: []
            }
          ) do |session: 'default', profile: nil, **|
            profile_sym = profile&.to_sym

            sessions.enable_stealth(session, profile: profile_sym)

            info = sessions.stealth_info(session)
            MCP::Tool::Response.new([{
              type: 'text',
              text: "Stealth mode enabled for session '#{session}' with profile: #{info[:profile]}"
            }])
          rescue Crucible::SessionNotFoundError, Crucible::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], is_error: true)
          end
        end

        # Tool: Disable stealth mode for a session
        def disable_stealth_tool(sessions)
          MCP::Tool.define(
            name: 'disable_stealth',
            description: 'Disable stealth mode for a browser session. Note: Already-applied evasions ' \
                         'cannot be removed, but this prevents new evasions from being applied.',
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
            sessions.disable_stealth(session)

            MCP::Tool::Response.new([{
              type: 'text',
              text: "Stealth mode disabled for session '#{session}'"
            }])
          rescue Crucible::SessionNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], is_error: true)
          end
        end

        # Tool: Get stealth status for a session
        def get_stealth_status_tool(sessions)
          MCP::Tool.define(
            name: 'get_stealth_status',
            description: 'Get the current stealth mode status for a browser session.',
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
            info = sessions.stealth_info(session)

            status = {
              session: session,
              stealth_enabled: info[:enabled],
              profile: info[:profile]
            }

            MCP::Tool::Response.new([{
              type: 'text',
              text: JSON.pretty_generate(status)
            }])
          rescue Crucible::SessionNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], is_error: true)
          end
        end

        # Tool: Set stealth profile (change profile for existing session)
        def set_stealth_profile_tool(sessions, _config)
          MCP::Tool.define(
            name: 'set_stealth_profile',
            description: 'Change the stealth profile for a session. This enables stealth mode with ' \
                         'the new profile if not already enabled.',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                profile: {
                  type: 'string',
                  enum: VALID_PROFILES,
                  description: 'Stealth profile: minimal, moderate, or maximum'
                }
              },
              required: ['profile']
            }
          ) do |profile:, session: 'default', **|
            unless VALID_PROFILES.include?(profile)
              raise Crucible::Error, "Invalid profile: #{profile}. Must be one of: #{VALID_PROFILES.join(', ')}"
            end

            sessions.enable_stealth(session, profile: profile.to_sym)

            MCP::Tool::Response.new([{
              type: 'text',
              text: "Stealth profile set to '#{profile}' for session '#{session}'"
            }])
          rescue Crucible::SessionNotFoundError, Crucible::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], is_error: true)
          end
        end
      end
    end
  end
end
