# Crucible

A Ruby MCP (Model Context Protocol) server for browser automation using [Ferrum](https://github.com/rubycdp/ferrum) and headless Chrome. Provides 29 tools that AI agents can use to control browsers, with built-in stealth mode to evade bot detection.

## Installation

```bash
git clone https://github.com/joshfng/crucible.git
cd crucible
bundle install
```

## Usage

### Running the Server

```bash
# Run with defaults (headless, 1280x720 viewport, 30s timeout)
./exe/crucible

# Run with visible browser
./exe/crucible --no-headless

# Full options
./exe/crucible \
  --no-headless \
  --width 1920 \
  --height 1080 \
  --timeout 60 \
  --chrome /usr/bin/chromium \
  --error-level debug
```

### CLI Options

| Option                      | Description                                 | Default     |
| --------------------------- | ------------------------------------------- | ----------- |
| `-c, --config FILE`         | Path to YAML configuration file             | auto-detect |
| `--[no-]headless`           | Run browser in headless mode                | `true`      |
| `-w, --width WIDTH`         | Viewport width in pixels                    | `1280`      |
| `-h, --height HEIGHT`       | Viewport height in pixels                   | `720`       |
| `--chrome PATH`             | Path to Chrome/Chromium executable          | auto-detect |
| `-t, --timeout SECONDS`     | Default timeout in seconds                  | `30`        |
| `--error-level LEVEL`       | Logging level (debug/info/warn/error)       | `warn`      |
| `--screenshot-format FMT`   | Default screenshot format (png/jpeg/base64) | `png`       |
| `--content-format FMT`      | Default content format (html/text)          | `html`      |
| `--[no-]stealth`            | Enable/disable stealth mode                 | `true`      |
| `--stealth-profile PROFILE` | Stealth profile (minimal/moderate/maximum)  | `moderate`  |
| `--stealth-locale LOCALE`   | Browser locale for stealth mode             | `en-US,en`  |

### Claude Code Integration

Add to your Claude Code MCP settings (`~/.claude/settings.json`):

```json
{
  "mcpServers": {
    "crucible": {
      "command": "ruby",
      "args": [
        "-I",
        "/path/to/crucible/lib",
        "/path/to/crucible/exe/crucible"
      ]
    }
  }
}
```

## Tools

### Navigation

| Tool       | Description                   |
| ---------- | ----------------------------- |
| `navigate` | Navigate browser to a URL     |
| `wait_for` | Wait for an element to appear |
| `back`     | Navigate back in history      |
| `forward`  | Navigate forward in history   |
| `refresh`  | Refresh the current page      |

### Interaction

| Tool            | Description                                           |
| --------------- | ----------------------------------------------------- |
| `click`         | Click an element (supports double-click, right-click) |
| `type`          | Type text into an input (with optional clear/submit)  |
| `fill_form`     | Fill multiple form fields at once                     |
| `select_option` | Select option from dropdown                           |
| `scroll`        | Scroll page or element into view                      |
| `hover`         | Hover over an element                                 |

### Extraction

| Tool          | Description                                                                      |
| ------------- | -------------------------------------------------------------------------------- |
| `screenshot`  | Take screenshot (viewport, full page, or element); save to file or return base64 |
| `get_content` | Get page content (HTML or text)                                                  |
| `pdf`         | Generate PDF of the page; save to file or return base64                          |
| `evaluate`    | Execute JavaScript and return result                                             |
| `get_url`     | Get current page URL                                                             |
| `get_title`   | Get current page title                                                           |

### Cookies

| Tool            | Description                        |
| --------------- | ---------------------------------- |
| `get_cookies`   | Get all cookies or specific cookie |
| `set_cookies`   | Set one or more cookies            |
| `clear_cookies` | Clear all or specific cookies      |

### Sessions

| Tool            | Description                      |
| --------------- | -------------------------------- |
| `list_sessions` | List all active browser sessions |
| `close_session` | Close a session or all sessions  |

### Downloads

| Tool                | Description                                       |
| ------------------- | ------------------------------------------------- |
| `set_download_path` | Set the directory for downloads                   |
| `wait_for_download` | Wait for a download to complete                   |
| `list_downloads`    | List all tracked downloads                        |
| `clear_downloads`   | Clear tracked downloads (optionally delete files) |

### Stealth

| Tool                  | Description                                           |
| --------------------- | ----------------------------------------------------- |
| `enable_stealth`      | Enable stealth mode for a session                     |
| `disable_stealth`     | Disable stealth mode for a session                    |
| `get_stealth_status`  | Get stealth mode status for a session                 |
| `set_stealth_profile` | Change the stealth profile (minimal/moderate/maximum) |

## Sessions

All tools accept an optional `session` parameter to manage multiple independent browser instances:

```
# These run in separate browsers
navigate(session: "login-flow", url: "https://example.com/login")
navigate(session: "signup-flow", url: "https://example.com/signup")

# List active sessions
list_sessions()
# => { "count": 2, "sessions": ["login-flow", "signup-flow"] }

# Close a specific session
close_session(session: "login-flow")

# Close all sessions
close_session(all: true)
```

Sessions are created automatically on first use and persist until explicitly closed.

## Example Workflows

### Basic Navigation

```
navigate(url: "https://example.com")
wait_for(selector: ".content")
get_content(format: "text")
```

### Form Submission

```
navigate(url: "https://example.com/login")
type(selector: "#email", text: "user@example.com")
type(selector: "#password", text: "secret123")
click(selector: "button[type=submit]")
wait_for(selector: ".dashboard")
```

### Screenshots & PDFs

```
# Viewport screenshot (returns base64)
screenshot()

# Full page screenshot
screenshot(full_page: true)

# Element screenshot
screenshot(selector: ".hero-image")

# Save to file
screenshot(path: "/tmp/page.png")
screenshot(format: "jpeg", quality: 90, path: "/tmp/page.jpg")

# PDF generation
pdf()                                    # Returns base64
pdf(path: "/tmp/page.pdf")               # Save to file
pdf(format: "Letter", landscape: true)   # Custom format
```

### JavaScript Execution

```
# Get page dimensions
evaluate(expression: "[window.innerWidth, window.innerHeight]")

# Scroll to top
evaluate(expression: "window.scrollTo(0, 0)")

# Get element count
evaluate(expression: "document.querySelectorAll('a').length")
```

### File Downloads

```
# Set download directory
set_download_path(path: "/tmp/downloads")

# Click download link and wait
click(selector: "a.download-btn")
wait_for_download(timeout: 30)

# List tracked downloads (persists across navigation)
list_downloads()

# Clear tracking and delete files
clear_downloads(delete_files: true)
```

## Stealth Mode

Stealth mode applies various evasion techniques to make headless Chrome appear as a regular browser to bot detection systems. It is enabled by default with the "moderate" profile.

### Stealth Profiles

| Profile    | Description                                             |
| ---------- | ------------------------------------------------------- |
| `minimal`  | Basic evasions (navigator.webdriver, window dimensions) |
| `moderate` | Common evasions for most use cases (default)            |
| `maximum`  | All evasions for strictest bot detection                |

### Evasions Applied

The stealth module includes evasions ported from [puppeteer-extra](https://github.com/berstend/puppeteer-extra):

- `navigator.webdriver` - Remove the webdriver flag
- `chrome.app` - Mock the chrome.app object
- `chrome.csi` - Mock the chrome.csi function
- `chrome.loadTimes` - Mock chrome.loadTimes
- `chrome.runtime` - Mock chrome.runtime for extensions
- `navigator.vendor` - Override navigator.vendor
- `navigator.languages` - Match Accept-Language header
- `navigator.plugins` - Mock plugins and mimeTypes
- `navigator.permissions` - Fix Notification.permission
- `navigator.hardwareConcurrency` - Set realistic core count
- `webgl.vendor` - Fix WebGL vendor/renderer
- `media.codecs` - Report support for proprietary codecs
- `iframe.contentWindow` - Fix iframe detection
- `window.outerdimensions` - Fix outerWidth/outerHeight
- User-Agent override - Strip "Headless" and fix platform

### Runtime Control

```
# Check stealth status
get_stealth_status(session: "default")

# Enable with maximum protection
enable_stealth(session: "default", profile: "maximum")

# Disable stealth (already-applied evasions remain)
disable_stealth(session: "default")

# Change profile
set_stealth_profile(session: "default", profile: "minimal")
```

### Configuration File

Create `~/.config/crucible/config.yml`:

```yaml
browser:
  headless: true
  window_size: [1280, 720]

stealth:
  enabled: true
  profile: moderate
  locale: "en-US,en"

server:
  log_level: info
```

## Project Structure

```
crucible/
├── exe/crucible                # CLI executable
├── crucible.gemspec            # Gem specification
├── Gemfile                     # Dependencies
├── Rakefile                    # Build tasks
├── lib/
│   ├── crucible.rb             # Main module
│   └── crucible/
│       ├── version.rb          # Version constant
│       ├── configuration.rb    # Config with YAML support
│       ├── session_manager.rb  # Multi-session management
│       ├── server.rb           # MCP server setup
│       ├── stealth.rb          # Stealth mode module
│       ├── stealth/
│       │   ├── utils.js        # Stealth utilities
│       │   └── evasions/       # Individual evasion scripts
│       └── tools/
│           ├── helpers.rb      # Shared utilities
│           ├── navigation.rb   # Navigation tools
│           ├── interaction.rb  # Interaction tools
│           ├── extraction.rb   # Extraction tools
│           ├── cookies.rb      # Cookie tools
│           ├── sessions.rb     # Session tools
│           ├── downloads.rb    # Download tools
│           └── stealth.rb      # Stealth control tools
└── spec/                       # RSpec tests
```

## Development

```bash
# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Interactive console
bundle exec rake console

# Run server in development
bundle exec rake server
```

## Releasing

```bash
bin/release 0.2.0
git push origin main --tags
gh release create v0.2.0 --generate-notes
```

The release workflow automatically publishes to RubyGems.

**Setup**: Add `RUBYGEMS_API_KEY` to repository secrets.

## Requirements

- Ruby >= 3.2.0
- Chrome or Chromium browser
- Dependencies:
  - `ferrum` ~> 0.15
  - `mcp` ~> 0.4

## License

MIT License. See [LICENSE](LICENSE) for details.
