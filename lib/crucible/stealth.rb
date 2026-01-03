# frozen_string_literal: true

module Crucible
  # Stealth mode for browser automation
  #
  # Applies various evasion techniques to make headless Chrome
  # appear as a regular browser to bot detection systems.
  #
  # @example
  #   stealth = Stealth.new(profile: :maximum)
  #   stealth.apply(browser)
  #
  class Stealth
    EVASIONS_PATH = File.expand_path('stealth/evasions', __dir__)
    UTILS_PATH = File.expand_path('stealth/utils.js', __dir__)

    # Stealth profiles define which evasions are enabled
    PROFILES = {
      # Minimal - only essential evasions
      minimal: %i[
        navigator_webdriver
        window_outerdimensions
      ],

      # Moderate - common evasions for most use cases
      moderate: %i[
        navigator_webdriver
        chrome_app
        chrome_csi
        chrome_load_times
        chrome_runtime
        navigator_vendor
        navigator_languages
        window_outerdimensions
      ],

      # Maximum - all evasions for strictest detection
      maximum: %i[
        navigator_webdriver
        chrome_app
        chrome_csi
        chrome_load_times
        chrome_runtime
        navigator_vendor
        navigator_languages
        navigator_plugins
        navigator_permissions
        navigator_hardware_concurrency
        webgl_vendor
        media_codecs
        iframe_content_window
        window_outerdimensions
      ]
    }.freeze

    # Evasion files with their configurable options
    EVASION_OPTIONS = {
      navigator_vendor: { vendor: 'Google Inc.' },
      navigator_languages: { languages: %w[en-US en] },
      navigator_hardware_concurrency: { hardwareConcurrency: 4 },
      webgl_vendor: { vendor: 'Intel Inc.', renderer: 'Intel Iris OpenGL Engine' }
    }.freeze

    attr_reader :profile, :enabled, :options

    # @param profile [Symbol] stealth profile (:minimal, :moderate, :maximum)
    # @param enabled [Boolean] whether stealth is enabled
    # @param options [Hash] additional options (locale, custom evasion opts)
    def initialize(profile: :moderate, enabled: true, **options)
      @profile = validate_profile(profile)
      @enabled = enabled
      @options = {
        locale: 'en-US,en',
        inject_utils: true
      }.merge(options)
    end

    # Apply stealth evasions to a browser
    # @param browser [Ferrum::Browser] the browser instance
    def apply(browser)
      return unless enabled

      inject_utils(browser) if options[:inject_utils]
      inject_evasions(browser)
      apply_user_agent_override(browser)
    end

    # Apply stealth evasions to a page (for new pages in existing session)
    # @param page [Ferrum::Page] the page instance
    def apply_to_page(page)
      return unless enabled

      inject_utils_to_page(page) if options[:inject_utils]
      inject_evasions_to_page(page)
    end

    # Get list of enabled evasions for current profile
    # @return [Array<Symbol>]
    def enabled_evasions
      PROFILES.fetch(profile, PROFILES[:moderate])
    end

    # Creates extensions array suitable for Ferrum browser options
    # @return [Array<String>]
    def extensions
      return [] unless enabled

      scripts = []
      scripts << utils_script if options[:inject_utils]
      scripts.concat(evasion_scripts)
      scripts
    end

    private

    def validate_profile(profile)
      profile = profile.to_sym
      unless PROFILES.key?(profile)
        raise Error, "Invalid stealth profile: #{profile}. Must be one of: #{PROFILES.keys.join(', ')}"
      end

      profile
    end

    def inject_utils(browser)
      # Use evaluate_on_new_document to inject before page loads
      browser.evaluate_on_new_document(utils_script)
    rescue Ferrum::Error
      # Browser may not be ready, that's OK
    end

    def inject_utils_to_page(page)
      # For existing pages, use command directly
      page.command('Page.addScriptToEvaluateOnNewDocument', source: utils_script)
    rescue Ferrum::Error
      # Page may not be ready, that's OK
    end

    def inject_evasions(browser)
      evasion_scripts.each do |script|
        browser.evaluate_on_new_document(script)
      rescue Ferrum::Error
        # Continue with other evasions
      end
    end

    def inject_evasions_to_page(page)
      evasion_scripts.each do |script|
        page.command('Page.addScriptToEvaluateOnNewDocument', source: script)
      rescue Ferrum::Error
        # Continue with other evasions
      end
    end

    def apply_user_agent_override(browser)
      page = browser.page
      return unless page

      # Get current UA and strip "Headless"
      ua = page.evaluate('navigator.userAgent')
      ua = ua.gsub('HeadlessChrome/', 'Chrome/')

      # Mask Linux as Windows (common detection vector)
      ua = ua.gsub(/\(([^)]+)\)/, '(Windows NT 10.0; Win64; x64)') if ua.include?('Linux') && !ua.include?('Android')

      # Apply via Ferrum's page command (uses Network.setUserAgentOverride internally)
      page.command(
        'Network.setUserAgentOverride',
        userAgent: ua,
        acceptLanguage: options[:locale]
      )
    rescue Ferrum::Error => e
      # Log but don't fail - UA override is optional
      warn "[Stealth] Failed to apply user agent override: #{e.message}"
    end

    def utils_script
      @utils_script ||= File.read(UTILS_PATH)
    end

    def evasion_scripts
      enabled_evasions.map do |evasion|
        script = load_evasion_script(evasion)
        substitute_options(evasion, script)
      end.compact
    end

    def load_evasion_script(evasion)
      path = File.join(EVASIONS_PATH, "#{evasion}.js")
      return nil unless File.exist?(path)

      File.read(path)
    end

    def substitute_options(evasion, script)
      return script unless script

      evasion_opts = EVASION_OPTIONS[evasion]
      return script unless evasion_opts

      # Merge with user-provided options
      merged_opts = evasion_opts.merge(options.fetch(evasion, {}))

      # Substitute options in the script
      # Scripts end with `})({ key: null }); // Will be replaced by Ruby`
      # rubocop:disable Style/RegexpLiteral
      script.gsub(/\}\)\(\{[^}]+\}\);?\s*(\/\/.*)?$/) do
        # rubocop:enable Style/RegexpLiteral
        "})(#{merged_opts.to_json});"
      end
    end
  end
end
