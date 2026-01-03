# Testing Guide

This document covers the testing setup and practices for Crucible.

## Running the Server

```bash
# Run directly (no bundle exec needed)
./exe/crucible

# With options
./exe/crucible --no-headless --width 1920 --height 1080

# Show all options
./exe/crucible --help
```

## Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with documentation format
bundle exec rspec --format doc

# Run specific test file
bundle exec rspec spec/tools/navigation_spec.rb

# Run specific test by line number
bundle exec rspec spec/tools/navigation_spec.rb:44

# Run tests matching a pattern
bundle exec rspec --example "navigate tool"
```

## Test Structure

```
spec/
├── spec_helper.rb           # Test configuration and helpers
├── crucible_spec.rb         # Core module tests
├── configuration_spec.rb    # Configuration validation tests
├── session_manager_spec.rb  # Session lifecycle tests
├── tools/
│   ├── navigation_spec.rb   # navigate, wait_for, back, forward, refresh
│   ├── interaction_spec.rb  # click, type, fill_form, select_option, scroll, hover
│   ├── extraction_spec.rb   # screenshot, get_content, pdf, evaluate, get_url, get_title
│   ├── cookies_spec.rb      # get_cookies, set_cookies, clear_cookies
│   ├── sessions_spec.rb     # list_sessions, close_session
│   └── downloads_spec.rb    # set_download_path, wait_for_download, list_downloads, clear_downloads
└── e2e/
    └── stealth_e2e_spec.rb  # End-to-end stealth mode tests
```

## Test Helper

The `ToolTestHelper` module provides a convenient way to call MCP tools in tests:

```ruby
module ToolTestHelper
  def call_tool(tool, args = {})
    tool.call(args, nil)
  end
end
```

MCP tools expect two arguments: `(args, context)`. The helper passes `nil` for context since tests don't need server context.

## Mocking Strategy

Tests use RSpec's `instance_double` to mock Ferrum objects:

```ruby
let(:session_manager) { instance_double(Crucible::SessionManager) }
let(:page) { instance_double("Ferrum::Page") }
let(:element) { instance_double("Ferrum::Node") }

before do
  allow(session_manager).to receive(:page).and_return(page)
end
```

### Why instance_double?

- Verifies mocked methods exist on the real class
- Catches API mismatches early (e.g., wrong method signatures)
- Provides clear error messages when expectations fail

### Important: Ferrum is loaded for real

The spec_helper loads the real Ferrum gem:

```ruby
require "ferrum"
```

This ensures `instance_double` can verify method signatures against the actual Ferrum API.

## Testing MCP Tool Schemas

MCP tools have input schemas that define their parameters. Test schema properties using the `.properties` and `.required` methods:

```ruby
it "has correct schema" do
  schema = tool.input_schema_value

  # Properties returns a hash with symbol keys
  expect(schema.properties).to have_key(:url)
  expect(schema.properties).to have_key(:session)

  # Required returns an array of symbols
  expect(schema.required).to include(:url)
end
```

**Note**: Schema methods return symbols, not strings:

- `schema.properties` → `{ url: {...}, session: {...} }`
- `schema.required` → `[:url]`

## Testing MCP Tool Responses

MCP tools return `MCP::Tool::Response` objects:

```ruby
# Successful response
result = call_tool(tool, url: "https://example.com")
expect(result.content.first[:text]).to include("Navigated to")
expect(result.error?).to be(false)

# Error response
result = call_tool(tool, url: "invalid")
expect(result.error?).to be(true)
expect(result.content.first[:text]).to include("failed")
```

### Response Structure

```ruby
result.content      # Array of content blocks
result.error?       # Boolean indicating error state
result.to_h         # Hash representation for MCP protocol
```

### Content Types

```ruby
# Text content
{ type: "text", text: "Success message" }

# Image content (screenshots)
{ type: "image", data: "base64...", mimeType: "image/png" }

# Resource content (PDFs)
{ type: "resource", resource: { uri: "...", mimeType: "application/pdf", blob: "..." } }
```

## Testing Error Handling

Tools should handle errors gracefully and return error responses:

```ruby
it "returns error on failure" do
  allow(page).to receive(:go_to).and_raise(Ferrum::Error.new("Connection refused"))

  result = call_tool(tool, url: "https://example.com")

  expect(result.error?).to be(true)
  expect(result.content.first[:text]).to include("Navigation failed")
end

it "returns error when element not found" do
  allow(page).to receive(:at_css).and_return(nil)

  result = call_tool(tool, selector: "#missing")

  expect(result.error?).to be(true)
  expect(result.content.first[:text]).to include("Element not found")
end
```

## Code Coverage

SimpleCov is configured to track coverage:

```ruby
require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  minimum_coverage 50
end
```

View the coverage report at `coverage/index.html` after running tests.

Current coverage:

- Line Coverage: ~87%
- Branch Coverage: ~75%

## Common Patterns

### Testing session parameter

Most tools accept an optional `session` parameter:

```ruby
it "uses specified session" do
  allow(page).to receive(:go_to)

  call_tool(tool, session: "my-session", url: "https://example.com")

  expect(session_manager).to have_received(:page).with("my-session")
end
```

### Testing optional parameters

```ruby
it "uses default format" do
  allow(page).to receive(:screenshot).with(hash_including(format: :png)).and_return("base64data")

  call_tool(tool)

  expect(page).to have_received(:screenshot).with(hash_including(format: :png))
end

it "respects custom format" do
  allow(page).to receive(:screenshot).with(hash_including(format: :jpeg)).and_return("base64data")

  call_tool(tool, format: "jpeg")

  expect(page).to have_received(:screenshot).with(hash_including(format: :jpeg))
end
```

## Ferrum API Reference

Key Ferrum methods used and their signatures:

```ruby
# Navigation
page.go_to(url)
page.back
page.forward
page.refresh

# Element finding
page.at_css(selector)           # Returns single element or nil

# Element interaction
element.click(mode: :left)      # :left, :right, or :double
element.hover
element.focus
element.type("text")
element.type("text", :Enter)    # Type with key
element.scroll_into_view

# Content extraction
page.body                       # Full HTML
page.current_url
page.current_title
element.text
element.property("outerHTML")

# JavaScript
page.evaluate("expression")
page.execute("script")

# Screenshots/PDF
page.screenshot(format: :png, full: false, quality: 100, path: "/tmp/screenshot.png")
page.pdf(landscape: false, format: :A4, scale: 1.0, path: "/tmp/page.pdf")

# Cookies
page.cookies.all               # Hash of all cookies
page.cookies[name]             # Get specific cookie
page.cookies.set(name:, value:, ...)
page.cookies.remove(name:, url:)
page.cookies.clear

# Downloads
browser.downloads.set_behavior(save_path: "/tmp/downloads")
browser.downloads.wait(timeout)
browser.downloads.files        # List of downloaded file paths
```

## Debugging Tests

```bash
# Run with full backtrace
bundle exec rspec --backtrace

# Run single test in isolation
bundle exec rspec spec/tools/navigation_spec.rb:44 --format doc

# Add binding.irb to pause execution
it "debugs something" do
  result = call_tool(tool, url: "https://example.com")
  binding.irb  # Pause here
  expect(result).to be_valid
end
```

## CI/CD Considerations

The test suite:

- Runs in ~2 seconds
- Requires no network access (all Ferrum calls mocked)
- Requires no Chrome/Chromium installation for unit tests
- Uses random test ordering (`config.order = :random`)

For integration tests that actually drive a browser, you would need:

- Chrome/Chromium installed
- Xvfb or headless mode on CI
- Longer timeouts for browser operations
