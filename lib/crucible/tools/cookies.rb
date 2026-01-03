# frozen_string_literal: true

require 'mcp'
require 'json'

module Crucible
  module Tools
    # Cookie management tools: get_cookies, set_cookies, clear_cookies
    module Cookies
      class << self
        def tools(sessions, _config)
          [
            get_cookies_tool(sessions),
            set_cookies_tool(sessions),
            clear_cookies_tool(sessions)
          ]
        end

        private

        def get_cookies_tool(sessions)
          MCP::Tool.define(
            name: 'get_cookies',
            description: 'Get cookies from the current page',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                name: {
                  type: 'string',
                  description: 'Specific cookie name to get (optional, returns all if not specified)'
                }
              },
              required: []
            }
          ) do |session: 'default', name: nil, **|
            page = sessions.page(session)

            # Helper to convert cookie to hash
            to_hash = lambda do |c|
              {
                name: c.name,
                value: c.value,
                domain: c.domain,
                path: c.path,
                secure: c.secure?,
                httpOnly: c.httponly?,
                sameSite: c.samesite,
                expires: c.expires
              }.compact
            end

            cookies = if name
                        cookie = page.cookies[name]
                        cookie ? [to_hash.call(cookie)] : []
                      else
                        page.cookies.all.values.map { |c| to_hash.call(c) }
                      end

            MCP::Tool::Response.new([{ type: 'text', text: JSON.pretty_generate(cookies) }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Get cookies failed: #{e.message}" }], error: true)
          end
        end

        def set_cookies_tool(sessions)
          MCP::Tool.define(
            name: 'set_cookies',
            description: 'Set one or more cookies',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                cookies: {
                  type: 'array',
                  description: 'Array of cookies to set',
                  items: {
                    type: 'object',
                    properties: {
                      name: {
                        type: 'string',
                        description: 'Cookie name'
                      },
                      value: {
                        type: 'string',
                        description: 'Cookie value'
                      },
                      domain: {
                        type: 'string',
                        description: 'Cookie domain'
                      },
                      path: {
                        type: 'string',
                        description: 'Cookie path',
                        default: '/'
                      },
                      secure: {
                        type: 'boolean',
                        description: 'Secure cookie flag',
                        default: false
                      },
                      httpOnly: {
                        type: 'boolean',
                        description: 'HttpOnly cookie flag',
                        default: false
                      },
                      sameSite: {
                        type: 'string',
                        description: 'SameSite attribute',
                        enum: %w[Strict Lax None]
                      },
                      expires: {
                        type: 'integer',
                        description: 'Expiration timestamp (Unix epoch)'
                      }
                    },
                    required: %w[name value]
                  }
                }
              },
              required: ['cookies']
            }
          ) do |cookies:, session: 'default', **|
            page = sessions.page(session)

            cookies.each do |cookie|
              cookie_opts = {
                name: cookie[:name] || cookie['name'],
                value: cookie[:value] || cookie['value']
              }

              # Add optional fields if present
              domain = cookie[:domain] || cookie['domain']
              cookie_opts[:domain] = domain if domain

              path = cookie[:path] || cookie['path']
              cookie_opts[:path] = path if path

              secure = cookie[:secure] || cookie['secure']
              cookie_opts[:secure] = secure unless secure.nil?

              http_only = cookie[:httpOnly] || cookie['httpOnly']
              cookie_opts[:httponly] = http_only unless http_only.nil?

              same_site = cookie[:sameSite] || cookie['sameSite']
              cookie_opts[:samesite] = same_site if same_site

              expires = cookie[:expires] || cookie['expires']
              cookie_opts[:expires] = expires if expires

              page.cookies.set(**cookie_opts)
            end

            MCP::Tool::Response.new([{ type: 'text', text: "Set #{cookies.size} cookie(s)" }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Set cookies failed: #{e.message}" }], error: true)
          end
        end

        def clear_cookies_tool(sessions)
          MCP::Tool.define(
            name: 'clear_cookies',
            description: 'Clear all cookies or a specific cookie',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                name: {
                  type: 'string',
                  description: 'Specific cookie name to clear (optional, clears all if not specified)'
                }
              },
              required: []
            }
          ) do |session: 'default', name: nil, **|
            page = sessions.page(session)

            if name
              # Ferrum requires domain or url to remove a specific cookie
              url = page.current_url
              page.cookies.remove(name: name, url: url)
              MCP::Tool::Response.new([{ type: 'text', text: "Cleared cookie: #{name}" }])
            else
              page.cookies.clear
              MCP::Tool::Response.new([{ type: 'text', text: 'Cleared all cookies' }])
            end
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Clear cookies failed: #{e.message}" }], error: true)
          end
        end
      end
    end
  end
end
