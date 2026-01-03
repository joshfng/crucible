# frozen_string_literal: true

require 'mcp'
require 'json'
require 'base64'

module Crucible
  module Tools
    # Extraction tools: screenshot, get_content, pdf, evaluate, get_url, get_title
    module Extraction
      class << self
        def tools(sessions, config)
          [
            screenshot_tool(sessions, config),
            get_content_tool(sessions, config),
            pdf_tool(sessions, config),
            evaluate_tool(sessions),
            get_url_tool(sessions),
            get_title_tool(sessions)
          ]
        end

        private

        def screenshot_tool(sessions, config)
          MCP::Tool.define(
            name: 'screenshot',
            description: 'Take a screenshot of the page or a specific element',
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
                  description: 'CSS selector for element screenshot (optional, captures full viewport if not specified)'
                },
                full_page: {
                  type: 'boolean',
                  description: 'Capture full scrollable page',
                  default: false
                },
                format: {
                  type: 'string',
                  description: 'Image format',
                  enum: %w[png jpeg],
                  default: 'png'
                },
                quality: {
                  type: 'integer',
                  description: 'JPEG quality (1-100)',
                  minimum: 1,
                  maximum: 100,
                  default: 80
                },
                path: {
                  type: 'string',
                  description: 'File path to save screenshot (if omitted, returns base64 data)'
                }
              },
              required: []
            }
          ) do |session: 'default', selector: nil, full_page: false, format: nil, quality: 80, path: nil, **|
            format = (format || config.screenshot_format.to_s).to_sym

            page = sessions.page(session)

            screenshot_opts = {
              format: format,
              quality: quality
            }

            # Either save to file or return base64
            if path
              screenshot_opts[:path] = File.expand_path(path)
            else
              screenshot_opts[:encoding] = :base64
            end

            if selector
              element = page.at_css(selector)
              raise ElementNotFoundError, "Element not found: #{selector}" unless element

              data = page.screenshot(**screenshot_opts, selector: selector)
            elsif full_page
              data = page.screenshot(**screenshot_opts, full: true)
            else
              data = page.screenshot(**screenshot_opts)
            end

            if path
              MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: "Screenshot saved to: #{screenshot_opts[:path]}"
                                      }])
            else
              mime_type = format == :jpeg ? 'image/jpeg' : 'image/png'
              MCP::Tool::Response.new([{
                                        type: 'image',
                                        data: data,
                                        mimeType: mime_type
                                      }])
            end
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Screenshot failed: #{e.message}" }], error: true)
          end
        end

        def get_content_tool(sessions, config)
          MCP::Tool.define(
            name: 'get_content',
            description: 'Get the content of the page or a specific element',
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
                  description: 'CSS selector for specific element (optional, gets full page if not specified)'
                },
                format: {
                  type: 'string',
                  description: 'Content format to return',
                  enum: %w[html text],
                  default: 'html'
                }
              },
              required: []
            }
          ) do |session: 'default', selector: nil, format: nil, **|
            format ||= config.content_format.to_s

            page = sessions.page(session)

            content = if selector
                        element = page.at_css(selector)
                        raise ElementNotFoundError, "Element not found: #{selector}" unless element

                        if format == 'text'
                          element.text
                        else
                          element.property('outerHTML')
                        end
                      elsif format == 'text'
                        body = page.at_css('body')
                        body ? body.text : ''
                      else
                        page.body
                      end

            MCP::Tool::Response.new([{ type: 'text', text: content || '' }])
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Get content failed: #{e.message}" }], error: true)
          end
        end

        def pdf_tool(sessions, _config)
          MCP::Tool.define(
            name: 'pdf',
            description: 'Generate a PDF of the current page',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                landscape: {
                  type: 'boolean',
                  description: 'Use landscape orientation',
                  default: false
                },
                format: {
                  type: 'string',
                  description: 'Paper format',
                  enum: %w[A4 Letter Legal Tabloid],
                  default: 'A4'
                },
                scale: {
                  type: 'number',
                  description: 'Scale factor (0.1 to 2.0)',
                  minimum: 0.1,
                  maximum: 2.0,
                  default: 1.0
                },
                print_background: {
                  type: 'boolean',
                  description: 'Print background graphics',
                  default: true
                },
                path: {
                  type: 'string',
                  description: 'File path to save PDF (if omitted, returns base64 data)'
                }
              },
              required: []
            }
          ) do |session: 'default', landscape: false, format: 'A4', scale: 1.0, print_background: true, path: nil, **|
            page = sessions.page(session)

            pdf_opts = {
              landscape: landscape,
              format: format.to_sym,
              scale: scale,
              print_background: print_background
            }

            if path
              expanded_path = File.expand_path(path)
              pdf_opts[:path] = expanded_path
              page.pdf(**pdf_opts)

              MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: "PDF saved to: #{expanded_path}"
                                      }])
            else
              pdf_opts[:encoding] = :base64
              pdf_data = page.pdf(**pdf_opts)

              MCP::Tool::Response.new([{
                                        type: 'resource',
                                        resource: {
                                          uri: "data:application/pdf;base64,#{pdf_data}",
                                          mimeType: 'application/pdf',
                                          text: pdf_data
                                        }
                                      }])
            end
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "PDF generation failed: #{e.message}" }], error: true)
          end
        end

        def evaluate_tool(sessions)
          MCP::Tool.define(
            name: 'evaluate',
            description: 'Execute JavaScript in the page context and return the result',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                expression: {
                  type: 'string',
                  description: 'JavaScript expression to evaluate'
                }
              },
              required: ['expression']
            }
          ) do |expression:, session: 'default', **|
            page = sessions.page(session)
            result = page.evaluate(expression)

            # Convert result to JSON for consistent output
            result_text = case result
                          when nil then 'null'
                          when String then result
                          else JSON.generate(result)
                          end

            MCP::Tool::Response.new([{ type: 'text', text: result_text }])
          rescue Ferrum::JavaScriptError => e
            MCP::Tool::Response.new([{ type: 'text', text: "JavaScript error: #{e.message}" }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Evaluate failed: #{e.message}" }], error: true)
          end
        end

        def get_url_tool(sessions)
          MCP::Tool.define(
            name: 'get_url',
            description: 'Get the current URL of the page',
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

            MCP::Tool::Response.new([{ type: 'text', text: page.current_url }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Get URL failed: #{e.message}" }], error: true)
          end
        end

        def get_title_tool(sessions)
          MCP::Tool.define(
            name: 'get_title',
            description: 'Get the title of the current page',
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

            MCP::Tool::Response.new([{ type: 'text', text: page.current_title || '' }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Get title failed: #{e.message}" }], error: true)
          end
        end
      end
    end
  end
end
