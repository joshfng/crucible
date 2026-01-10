# frozen_string_literal: true

require_relative 'lib/crucible/version'

Gem::Specification.new do |spec|
  spec.name = 'crucible'
  spec.version = Crucible::VERSION
  spec.authors = ['Josh Frye']
  spec.email = ['me@joshfrye.dev']

  spec.summary = 'MCP server for browser automation using Ferrum/Chrome'
  spec.description = <<~DESC
    An MCP (Model Context Protocol) server that provides browser automation tools
    for AI agents using Ferrum and headless Chrome. Features 25 tools covering
    navigation, screenshots, form interaction, JavaScript evaluation, cookies,
    file downloads, and multi-session management.
  DESC
  spec.homepage = 'https://github.com/joshfng/crucible'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'ferrum', '~> 0.17.1'
  spec.add_dependency 'mcp', '~> 0.4.0'

  # Development dependencies
  spec.add_development_dependency 'rake', '~> 13.3'
  spec.add_development_dependency 'rspec', '~> 3.13'
  spec.add_development_dependency 'rubocop', '~> 1.82'
  spec.add_development_dependency 'rubocop-rake', '~> 0.7.1'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.9'
  spec.add_development_dependency 'simplecov', '~> 0.22.0'
end
