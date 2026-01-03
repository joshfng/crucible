# frozen_string_literal: true

require 'yaml'

module Crucible
  # Configuration for the Crucible server
  #
  # Supports both programmatic configuration and YAML config files.
  #
  # @example Programmatic configuration
  #   config = Crucible::Configuration.new(headless: false, timeout: 60)
  #   config.viewport_width = 1920
  #
  # @example From YAML file
  #   config = Crucible::Configuration.from_file("~/.config/crucible/config.yml")
  #
  class Configuration
    DEFAULT_CONFIG_PATHS = [
      '~/.config/crucible/config.yml',
      '~/.crucible.yml',
      '.crucible.yml'
    ].freeze

    DEFAULTS = {
      headless: true,
      viewport_width: 1280,
      viewport_height: 720,
      chrome_path: nil,
      timeout: 30,
      error_level: :warn,
      screenshot_format: :png,
      content_format: :html,
      # Stealth settings
      stealth_enabled: true,
      stealth_profile: :moderate,
      stealth_locale: 'en-US,en',
      # Mode settings
      mode: nil,
      log_file: nil
    }.freeze

    VALID_ERROR_LEVELS = %i[debug info warn error].freeze
    VALID_SCREENSHOT_FORMATS = %i[png jpeg base64].freeze
    VALID_CONTENT_FORMATS = %i[html text].freeze
    VALID_STEALTH_PROFILES = %i[minimal moderate maximum].freeze

    attr_accessor(*DEFAULTS.keys, :modes)

    # Load configuration from a YAML file
    # @param path [String] path to the YAML config file
    # @return [Configuration]
    def self.from_file(path)
      expanded_path = File.expand_path(path)
      raise Error, "Config file not found: #{expanded_path}" unless File.exist?(expanded_path)

      yaml = YAML.safe_load_file(expanded_path, symbolize_names: true)
      from_yaml_hash(yaml)
    end

    # Load configuration from default locations
    # @return [Configuration] config from first found file, or defaults
    def self.from_defaults
      DEFAULT_CONFIG_PATHS.each do |path|
        expanded = File.expand_path(path)
        return from_file(expanded) if File.exist?(expanded)
      end

      new
    end

    # Create configuration from a parsed YAML hash
    # @param yaml [Hash] parsed YAML configuration
    # @return [Configuration]
    def self.from_yaml_hash(yaml)
      options = {}

      # Browser settings
      if yaml[:browser]
        options[:headless] = yaml[:browser][:headless] if yaml[:browser].key?(:headless)
        if yaml[:browser][:window_size].is_a?(Array)
          options[:viewport_width] = yaml[:browser][:window_size][0]
          options[:viewport_height] = yaml[:browser][:window_size][1]
        end
        options[:chrome_path] = yaml[:browser][:chrome_path] if yaml[:browser][:chrome_path]
        options[:timeout] = yaml[:browser][:timeout] if yaml[:browser][:timeout]
      end

      # Stealth settings
      if yaml[:stealth]
        options[:stealth_enabled] = yaml[:stealth][:enabled] if yaml[:stealth].key?(:enabled)
        options[:stealth_profile] = yaml[:stealth][:profile]&.to_sym if yaml[:stealth][:profile]
        options[:stealth_locale] = yaml[:stealth][:locale] if yaml[:stealth][:locale]
      end

      # Server settings
      if yaml[:server]
        options[:error_level] = yaml[:server][:log_level]&.to_sym if yaml[:server][:log_level]
        options[:log_file] = yaml[:server][:logfile] if yaml[:server][:logfile]
      end

      config = new(options)

      # Store modes for runtime switching
      config.modes = yaml[:modes] if yaml[:modes]

      config
    end

    # @param options [Hash] configuration options
    def initialize(options = {})
      DEFAULTS.each do |key, default|
        value = options.fetch(key, default)
        # Symbolize string keys for enums
        value = value.to_sym if value.is_a?(String) && enum_key?(key)
        instance_variable_set(:"@#{key}", value)
      end
      @modes = {}
    end

    # Creates a new Configuration with merged options
    # @param options [Hash] options to merge
    # @return [Configuration]
    def merge(options)
      self.class.new(to_h.merge(options))
    end

    # Converts configuration to a hash
    # @return [Hash]
    def to_h
      DEFAULTS.keys.to_h { |k| [k, instance_variable_get(:"@#{k}")] }
    end

    # Returns options suitable for Ferrum::Browser.new
    # @return [Hash]
    def browser_options
      opts = {
        headless: headless,
        window_size: [viewport_width, viewport_height],
        timeout: timeout,
        process_timeout: timeout * 2
      }
      opts[:browser_path] = chrome_path if chrome_path
      opts
    end

    # Creates a Stealth instance based on configuration
    # @return [Stealth]
    def stealth
      Stealth.new(
        profile: stealth_profile,
        enabled: stealth_enabled,
        locale: stealth_locale
      )
    end

    # Apply a named mode from the modes configuration
    # @param mode_name [String, Symbol] the mode to apply
    # @return [Configuration] self with mode settings applied
    def apply_mode(mode_name)
      mode_name = mode_name.to_sym
      return self unless modes && modes[mode_name]

      mode_config = modes[mode_name]

      self.stealth_profile = mode_config[:stealth_profile]&.to_sym if mode_config[:stealth_profile]
      self.screenshot_format = mode_config[:screenshot_format]&.to_sym if mode_config[:screenshot_format]
      self.timeout = mode_config[:wait_timeout] / 1000 if mode_config[:wait_timeout]

      @mode = mode_name
      self
    end

    # Get list of available mode names
    # @return [Array<Symbol>]
    def available_modes
      modes&.keys || []
    end

    # Validates the configuration
    # @raise [Error] if configuration is invalid
    def validate!
      raise Error, 'Timeout must be positive' unless timeout.positive?
      raise Error, 'Viewport width must be positive' unless viewport_width.positive?
      raise Error, 'Viewport height must be positive' unless viewport_height.positive?

      unless VALID_ERROR_LEVELS.include?(error_level)
        raise Error, "Invalid error_level: #{error_level}. Must be one of: #{VALID_ERROR_LEVELS.join(', ')}"
      end

      unless VALID_SCREENSHOT_FORMATS.include?(screenshot_format)
        raise Error,
              "Invalid screenshot_format: #{screenshot_format}. Must be one of: #{VALID_SCREENSHOT_FORMATS.join(', ')}"
      end

      unless VALID_CONTENT_FORMATS.include?(content_format)
        raise Error, "Invalid content_format: #{content_format}. Must be one of: #{VALID_CONTENT_FORMATS.join(', ')}"
      end

      unless VALID_STEALTH_PROFILES.include?(stealth_profile)
        raise Error, "Invalid stealth_profile: #{stealth_profile}. Must be one of: #{VALID_STEALTH_PROFILES.join(', ')}"
      end

      true
    end

    private

    def enum_key?(key)
      %i[error_level screenshot_format content_format stealth_profile].include?(key)
    end
  end
end
