# frozen_string_literal: true

require 'mcp'
require 'json'
require 'fileutils'

module Crucible
  module Tools
    # Download management tools: set_download_path, list_downloads, wait_for_download, clear_downloads
    module Downloads
      # Tracker to persist download info across navigations (Ferrum clears its list on navigation)
      class Tracker
        def initialize
          @sessions = {}
          @mutex = Mutex.new
        end

        def set_path(session, path)
          @mutex.synchronize do
            @sessions[session] ||= { path: nil, files: [], initial_files: [] }
            @sessions[session][:path] = path
            # Capture initial directory state to detect new downloads
            @sessions[session][:initial_files] = Dir.exist?(path) ? Dir.glob(File.join(path, '*')) : []
          end
        end

        def get_path(session)
          @mutex.synchronize { @sessions.dig(session, :path) }
        end

        def get_initial_files(session)
          @mutex.synchronize { @sessions.dig(session, :initial_files) || [] }
        end

        def add_files(session, files)
          @mutex.synchronize do
            @sessions[session] ||= { path: nil, files: [], initial_files: [] }
            @sessions[session][:files] = (@sessions[session][:files] + files).uniq
          end
        end

        def get_files(session)
          @mutex.synchronize { @sessions.dig(session, :files) || [] }
        end

        def clear_files(session)
          @mutex.synchronize do
            cleared = @sessions.dig(session, :files) || []
            @sessions[session][:files] = [] if @sessions[session]
            cleared
          end
        end

        def remove_session(session)
          @mutex.synchronize { @sessions.delete(session) }
        end
      end

      class << self
        def tools(sessions, _config)
          # Create a shared tracker instance for all tools
          tracker = Tracker.new

          [
            set_download_path_tool(sessions, tracker),
            list_downloads_tool(sessions, tracker),
            wait_for_download_tool(sessions, tracker),
            clear_downloads_tool(sessions, tracker)
          ]
        end

        private

        def set_download_path_tool(sessions, tracker)
          MCP::Tool.define(
            name: 'set_download_path',
            description: 'Set the directory where downloads will be saved',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                path: {
                  type: 'string',
                  description: 'Directory path for downloads'
                }
              },
              required: ['path']
            }
          ) do |path:, session: 'default', **|
            browser = sessions.get_or_create(session)
            expanded_path = File.expand_path(path)

            # Create directory if it doesn't exist
            FileUtils.mkdir_p(expanded_path)

            # Set in Ferrum
            browser.downloads.set_behavior(save_path: expanded_path)

            # Track in our persistent tracker
            tracker.set_path(session, expanded_path)

            MCP::Tool::Response.new([{
                                      type: 'text',
                                      text: "Download path set to: #{expanded_path}"
                                    }])
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Failed to set download path: #{e.message}" }], error: true)
          end
        end

        def list_downloads_tool(_sessions, tracker)
          MCP::Tool.define(
            name: 'list_downloads',
            description: 'List all downloaded files in the current session',
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
            # Use our tracker instead of Ferrum's (which gets cleared on navigation)
            files = tracker.get_files(session)

            if files.empty?
              MCP::Tool::Response.new([{ type: 'text', text: 'No downloads in this session' }])
            else
              result = {
                download_path: tracker.get_path(session),
                count: files.size,
                files: files.map do |file|
                  info = { path: file, filename: File.basename(file) }
                  if File.exist?(file)
                    info[:size] = File.size(file)
                    info[:modified] = File.mtime(file).iso8601
                    info[:exists] = true
                  else
                    info[:exists] = false
                  end
                  info
                end
              }
              MCP::Tool::Response.new([{ type: 'text', text: JSON.pretty_generate(result) }])
            end
          end
        end

        def wait_for_download_tool(sessions, tracker)
          MCP::Tool.define(
            name: 'wait_for_download',
            description: 'Wait for a download to complete',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                timeout: {
                  type: 'number',
                  description: 'Maximum time to wait in seconds',
                  default: 30
                }
              },
              required: []
            }
          ) do |session: 'default', timeout: 30, **|
            browser = sessions.get_or_create(session)
            download_path = tracker.get_path(session)

            # Try Ferrum's wait first (may or may not work depending on download type)
            begin
              browser.downloads.wait(timeout)
            rescue Ferrum::TimeoutError
              # Timeout is ok - download might have already completed
            end

            # Find new files by comparing current directory against:
            # 1. Initial files when set_download_path was called
            # 2. Files we've already tracked
            new_files = []
            if download_path && Dir.exist?(download_path)
              current_files = Dir.glob(File.join(download_path, '*'))
              initial_files = tracker.get_initial_files(session)
              already_tracked = tracker.get_files(session)
              known_files = (initial_files + already_tracked).uniq

              new_files = current_files - known_files
            end

            # Add to our persistent tracker
            tracker.add_files(session, new_files) unless new_files.empty?

            if new_files.empty?
              tracked_count = tracker.get_files(session).size
              MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: "No new downloads. Total tracked files: #{tracked_count}"
                                      }])
            else
              result = new_files.map do |file|
                info = { path: file, filename: File.basename(file) }
                info[:size] = File.size(file) if File.exist?(file)
                info
              end
              MCP::Tool::Response.new([{
                                        type: 'text',
                                        text: "Downloaded: #{JSON.pretty_generate(result)}"
                                      }])
            end
          rescue Ferrum::Error => e
            MCP::Tool::Response.new([{ type: 'text', text: "Failed waiting for download: #{e.message}" }], error: true)
          end
        end

        def clear_downloads_tool(_sessions, tracker)
          MCP::Tool.define(
            name: 'clear_downloads',
            description: 'Clear the list of tracked downloads (optionally delete files)',
            input_schema: {
              type: 'object',
              properties: {
                session: {
                  type: 'string',
                  description: 'Session name',
                  default: 'default'
                },
                delete_files: {
                  type: 'boolean',
                  description: 'Also delete the actual files from disk',
                  default: false
                }
              },
              required: []
            }
          ) do |session: 'default', delete_files: false, **|
            files = tracker.clear_files(session)

            deleted_count = 0
            if delete_files
              files.each do |file|
                if File.exist?(file)
                  File.delete(file)
                  deleted_count += 1
                end
              end
            end

            message = if delete_files
                        "Cleared #{files.size} download(s), deleted #{deleted_count} file(s)"
                      else
                        "Cleared #{files.size} download(s) from tracking"
                      end

            MCP::Tool::Response.new([{ type: 'text', text: message }])
          rescue StandardError => e
            MCP::Tool::Response.new([{ type: 'text', text: "Failed to clear downloads: #{e.message}" }], error: true)
          end
        end
      end
    end
  end
end
