# frozen_string_literal: true

module Crucible
  # Tool registry and loader for MCP browser automation tools
  #
  # Tools are organized by domain:
  # - Navigation: navigate, wait_for, back, forward, refresh
  # - Interaction: click, type, fill_form, select_option, scroll, hover
  # - Extraction: screenshot, get_content, pdf, evaluate, get_url, get_title
  # - Cookies: get_cookies, set_cookies, clear_cookies
  # - Sessions: list_sessions, close_session
  # - Downloads: set_download_path, list_downloads, wait_for_download, clear_downloads
  #
  module Tools
    autoload :Helpers, 'crucible/tools/helpers'
    autoload :Navigation, 'crucible/tools/navigation'
    autoload :Interaction, 'crucible/tools/interaction'
    autoload :Extraction, 'crucible/tools/extraction'
    autoload :Cookies, 'crucible/tools/cookies'
    autoload :Sessions, 'crucible/tools/sessions'
    autoload :Downloads, 'crucible/tools/downloads'
    autoload :Stealth, 'crucible/tools/stealth'

    class << self
      # Returns all tool definitions for the MCP server
      # @param session_manager [SessionManager] the session manager instance
      # @param config [Configuration] the server configuration
      # @return [Array] array of MCP tool definitions
      def all(session_manager, config)
        [
          *Navigation.tools(session_manager, config),
          *Interaction.tools(session_manager, config),
          *Extraction.tools(session_manager, config),
          *Cookies.tools(session_manager, config),
          *Sessions.tools(session_manager, config),
          *Downloads.tools(session_manager, config),
          *Stealth.tools(session_manager, config)
        ]
      end
    end
  end
end
