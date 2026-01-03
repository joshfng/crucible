# frozen_string_literal: true

module Crucible
  module Tools
    # Shared helper methods for tool implementations
    module Helpers
      # Extracts an argument value, checking both symbol and string keys
      # @param args [Hash] the arguments hash from MCP
      # @param key [Symbol] the key to look for
      # @param default [Object] default value if not found
      # @return [Object] the argument value or default
      def extract_arg(args, key, default = nil)
        args.fetch(key) { args.fetch(key.to_s, default) }
      end

      # Returns the platform-appropriate modifier key for keyboard shortcuts
      # @return [Symbol] :meta on macOS, :control elsewhere
      def select_all_modifier
        RUBY_PLATFORM.include?('darwin') ? :meta : :control
      end

      # Clears an input field by selecting all and deleting
      # @param element [Ferrum::Node] the input element
      def clear_field(element)
        element.focus
        element.type([select_all_modifier, 'a'], [:backspace])
      end

      # Converts a Ferrum cookie to a hash
      # @param cookie [Ferrum::Cookie] the cookie object
      # @return [Hash] cookie as a hash
      def cookie_to_hash(cookie)
        {
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain,
          path: cookie.path,
          secure: cookie.secure?,
          httpOnly: cookie.httponly?,
          sameSite: cookie.samesite,
          expires: cookie.expires
        }.compact
      end
    end
  end
end
