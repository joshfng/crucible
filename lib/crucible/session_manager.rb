# frozen_string_literal: true

require 'ferrum'

module Crucible
  # Manages multiple named browser sessions
  #
  # Thread-safe session management with lazy browser initialization.
  # Each session maintains its own Ferrum::Browser instance.
  # Supports per-session stealth mode settings.
  #
  # @example
  #   manager = SessionManager.new(config)
  #   page = manager.page("my-session")
  #   page.go_to("https://example.com")
  #   manager.close("my-session")
  #
  class SessionManager
    # Session metadata
    SessionInfo = Struct.new(:browser, :stealth, :stealth_enabled, keyword_init: true)

    # @param config [Configuration] the server configuration
    def initialize(config)
      @config = config
      @sessions = {}
      @mutex = Mutex.new
    end

    # Gets or creates a session by name, returning the browser
    # @param name [String] session name (default: "default")
    # @return [Ferrum::Browser]
    def get_or_create(name = 'default')
      @mutex.synchronize do
        @sessions[name] ||= create_session
        @sessions[name].browser
      end
    end

    # Gets an existing session by name
    # @param name [String] session name
    # @return [Ferrum::Browser]
    # @raise [SessionNotFoundError] if session doesn't exist
    def get(name)
      info = @mutex.synchronize { @sessions[name] }
      raise SessionNotFoundError, "Session '#{name}' not found. Use get_or_create or navigate first." unless info

      info.browser
    end

    # Convenience method to get the page for a session
    # @param name [String] session name (default: "default")
    # @return [Ferrum::Page]
    def page(name = 'default')
      browser = get_or_create(name)
      browser.page || browser.create_page
    end

    # Creates a new named session
    # @param name [String] session name
    # @return [Ferrum::Browser]
    # @raise [Error] if session already exists
    def create(name)
      @mutex.synchronize do
        raise Error, "Session '#{name}' already exists" if @sessions.key?(name)

        @sessions[name] = create_session
        @sessions[name].browser
      end
    end

    # Closes a session and quits its browser
    # @param name [String] session name
    # @return [Boolean] true if session was closed, false if not found
    def close(name)
      info = @mutex.synchronize { @sessions.delete(name) }
      return false unless info

      info.browser.quit
      true
    rescue Ferrum::Error
      # Browser may already be dead
      true
    end

    # Closes all sessions
    def close_all
      sessions = @mutex.synchronize do
        result = @sessions.values
        @sessions.clear
        result
      end

      sessions.each do |info|
        info.browser.quit
      rescue Ferrum::Error
        # Ignore errors during shutdown
      end
    end

    # Lists all active session names
    # @return [Array<String>]
    def list
      @mutex.synchronize { @sessions.keys.dup }
    end

    # Checks if a session exists
    # @param name [String] session name
    # @return [Boolean]
    def exists?(name)
      @mutex.synchronize { @sessions.key?(name) }
    end

    # Returns the count of active sessions
    # @return [Integer]
    def count
      @mutex.synchronize { @sessions.size }
    end

    # Enable stealth mode for a session
    # @param name [String] session name
    # @param profile [Symbol] stealth profile (:minimal, :moderate, :maximum)
    # @return [Boolean] true if stealth was enabled
    def enable_stealth(name, profile: nil)
      info = @mutex.synchronize { @sessions[name] }
      raise SessionNotFoundError, "Session '#{name}' not found" unless info

      profile ||= @config.stealth_profile
      stealth = Stealth.new(profile: profile, enabled: true, locale: @config.stealth_locale)

      # Apply stealth to the browser
      stealth.apply(info.browser)

      # Update session metadata
      @mutex.synchronize do
        @sessions[name] = SessionInfo.new(
          browser: info.browser,
          stealth: stealth,
          stealth_enabled: true
        )
      end

      true
    end

    # Disable stealth mode for a session
    # Note: This won't undo already-applied evasions, but prevents new ones
    # @param name [String] session name
    # @return [Boolean] true if stealth was disabled
    def disable_stealth(name)
      info = @mutex.synchronize { @sessions[name] }
      raise SessionNotFoundError, "Session '#{name}' not found" unless info

      @mutex.synchronize do
        @sessions[name] = SessionInfo.new(
          browser: info.browser,
          stealth: info.stealth,
          stealth_enabled: false
        )
      end

      true
    end

    # Check if stealth is enabled for a session
    # @param name [String] session name
    # @return [Boolean]
    def stealth_enabled?(name)
      info = @mutex.synchronize { @sessions[name] }
      return false unless info

      info.stealth_enabled
    end

    # Get stealth info for a session
    # @param name [String] session name
    # @return [Hash] stealth status and profile
    def stealth_info(name)
      info = @mutex.synchronize { @sessions[name] }
      raise SessionNotFoundError, "Session '#{name}' not found" unless info

      {
        enabled: info.stealth_enabled,
        profile: info.stealth&.profile&.to_s
      }
    end

    private

    def create_session
      browser = create_browser
      stealth = @config.stealth

      # Apply stealth if enabled in config
      stealth.apply(browser) if @config.stealth_enabled

      SessionInfo.new(
        browser: browser,
        stealth: stealth,
        stealth_enabled: @config.stealth_enabled
      )
    rescue Ferrum::Error => e
      raise BrowserError, "Failed to create browser: #{e.message}"
    end

    def create_browser
      Ferrum::Browser.new(@config.browser_options)
    end
  end
end
