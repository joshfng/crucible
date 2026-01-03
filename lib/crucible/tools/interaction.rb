# frozen_string_literal: true

require 'mcp'

module Crucible
  module Tools
    # Interaction tools: click, type, fill_form, select_option, scroll, hover
    module Interaction
      class << self
        def tools(sessions, _config)
          [
            click_tool(sessions),
            type_tool(sessions),
            fill_form_tool(sessions),
            select_option_tool(sessions),
            scroll_tool(sessions),
            hover_tool(sessions)
          ]
        end

        private

        def click_tool(sessions)
          MCP::Tool.define(
            name: 'click',
            description: 'Click an element on the page',
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
                  description: 'CSS selector for the element to click'
                },
                button: {
                  type: 'string',
                  description: 'Mouse button to use',
                  enum: %w[left right middle],
                  default: 'left'
                },
                count: {
                  type: 'integer',
                  description: 'Number of clicks (1 for single, 2 for double)',
                  default: 1
                }
              },
              required: ['selector']
            }
          ) do |selector:, session: 'default', button: 'left', count: 1, **|
            page = sessions.page(session)
            element = page.at_css(selector)

            raise ElementNotFoundError, "Element not found: #{selector}" unless element

            # Ferrum uses mode: for click type - :left, :right, or :double
            mode = if count == 2
                     :double
                   else
                     button.to_sym
                   end

            element.click(mode: mode)

            MCP::Tool::Response.new([{ type: 'text', text: "Clicked: #{selector}" }])
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Click failed: #{e.message}" }], error: true)
          end
        end

        def type_tool(sessions)
          MCP::Tool.define(
            name: 'type',
            description: 'Type text into an input element',
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
                  description: 'CSS selector for the input element'
                },
                text: {
                  type: 'string',
                  description: 'Text to type'
                },
                clear: {
                  type: 'boolean',
                  description: 'Clear the field before typing',
                  default: false
                },
                submit: {
                  type: 'boolean',
                  description: 'Press Enter after typing',
                  default: false
                }
              },
              required: %w[selector text]
            }
          ) do |selector:, text:, session: 'default', clear: false, submit: false, **|
            page = sessions.page(session)
            element = page.at_css(selector)

            raise ElementNotFoundError, "Element not found: #{selector}" unless element

            element.focus

            if clear
              # Select all and delete (use meta on macOS, control elsewhere)
              modifier = RUBY_PLATFORM.include?('darwin') ? :meta : :control
              element.type([modifier, 'a'], [:backspace])
            end

            if submit
              element.type(text, :Enter)
            else
              element.type(text)
            end

            MCP::Tool::Response.new([{ type: 'text', text: "Typed into: #{selector}" }])
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Type failed: #{e.message}" }], error: true)
          end
        end

        def fill_form_tool(sessions)
          MCP::Tool.define(
            name: 'fill_form',
            description: 'Fill multiple form fields at once',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                fields: {
                  type: 'array',
                  description: 'Array of fields to fill',
                  items: {
                    type: 'object',
                    properties: {
                      selector: {
                        type: 'string',
                        description: 'CSS selector for the field'
                      },
                      value: {
                        type: 'string',
                        description: 'Value to enter'
                      }
                    },
                    required: %w[selector value]
                  }
                }
              },
              required: ['fields']
            }
          ) do |fields:, session: 'default', **|
            page = sessions.page(session)
            filled = []
            errors = []

            fields.each do |field|
              field_selector = field[:selector] || field['selector']
              value = field[:value] || field['value']

              element = page.at_css(field_selector)
              if element
                element.focus
                # Clear first (use meta on macOS, control elsewhere)
                modifier = RUBY_PLATFORM.include?('darwin') ? :meta : :control
                element.type([modifier, 'a'], [:backspace])
                element.type(value)
                filled << field_selector
              else
                errors << field_selector
              end
            end

            message = "Filled #{filled.size} field(s)"
            message += ". Not found: #{errors.join(', ')}" if errors.any?

            if errors.any? && filled.empty?
              MCP::Tool::Response.new([{ type: 'text', text: message }], error: true)
            else
              MCP::Tool::Response.new([{ type: 'text', text: message }])
            end
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Fill form failed: #{e.message}" }], error: true)
          end
        end

        def select_option_tool(sessions)
          MCP::Tool.define(
            name: 'select_option',
            description: 'Select an option from a dropdown/select element',
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
                  description: 'CSS selector for the select element'
                },
                value: {
                  type: 'string',
                  description: 'Value or text of the option to select'
                },
                by: {
                  type: 'string',
                  description: 'How to match the option',
                  enum: %w[value text],
                  default: 'value'
                }
              },
              required: %w[selector value]
            }
          ) do |selector:, value:, session: 'default', by: 'value', **|
            _ = by # TODO: Implement selection by text/index

            page = sessions.page(session)
            select = page.at_css(selector)

            raise ElementNotFoundError, "Select element not found: #{selector}" unless select

            select.select(value)

            MCP::Tool::Response.new([{ type: 'text', text: "Selected '#{value}' in: #{selector}" }])
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Select failed: #{e.message}" }], error: true)
          end
        end

        def scroll_tool(sessions)
          MCP::Tool.define(
            name: 'scroll',
            description: 'Scroll the page or scroll an element into view',
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
                  description: 'CSS selector to scroll into view (optional)'
                },
                x: {
                  type: 'integer',
                  description: 'Horizontal scroll amount in pixels',
                  default: 0
                },
                y: {
                  type: 'integer',
                  description: 'Vertical scroll amount in pixels',
                  default: 0
                },
                direction: {
                  type: 'string',
                  description: 'Scroll direction shortcut',
                  enum: %w[up down left right top bottom]
                }
              },
              required: []
            }
          ) do |session: 'default', selector: nil, x: 0, y: 0, direction: nil, **|
            page = sessions.page(session)

            if selector
              # Scroll element into view
              element = page.at_css(selector)
              raise ElementNotFoundError, "Element not found: #{selector}" unless element

              element.scroll_into_view
              MCP::Tool::Response.new([{ type: 'text', text: "Scrolled into view: #{selector}" }])
            else
              # Scroll by coordinates or direction
              scroll_x, scroll_y = case direction
                                   when 'up' then [0, -500]
                                   when 'down' then [0, 500]
                                   when 'left' then [-500, 0]
                                   when 'right' then [500, 0]
                                   when 'top' then [0, -100_000]
                                   when 'bottom' then [0, 100_000]
                                   else [x, y]
                                   end

              page.execute("window.scrollBy(#{scroll_x}, #{scroll_y})")
              MCP::Tool::Response.new([{ type: 'text', text: "Scrolled by (#{scroll_x}, #{scroll_y})" }])
            end
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Scroll failed: #{e.message}" }], error: true)
          end
        end

        def hover_tool(sessions)
          MCP::Tool.define(
            name: 'hover',
            description: 'Hover over an element',
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
                  description: 'CSS selector for the element to hover'
                }
              },
              required: ['selector']
            }
          ) do |selector:, session: 'default', **|
            page = sessions.page(session)
            element = page.at_css(selector)

            raise ElementNotFoundError, "Element not found: #{selector}" unless element

            element.hover

            MCP::Tool::Response.new([{ type: 'text', text: "Hovering over: #{selector}" }])
          rescue ElementNotFoundError => e
            MCP::Tool::Response.new([{ type: 'text', text: e.message }], error: true)
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Hover failed: #{e.message}" }], error: true)
          end
        end
      end
    end
  end
end
