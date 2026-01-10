# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

# End-to-end tests for stealth mode against real bot detection sites
# Run with: bundle exec rspec spec/e2e/ --tag e2e
#
# These tests require network access and take longer to run.
# They verify that stealth evasions work against real detection systems.
RSpec.describe 'Stealth E2E', :e2e do
  let(:screenshot_dir) { File.expand_path('../../tmp/screenshots', __dir__) }

  before(:all) do
    FileUtils.mkdir_p(File.expand_path('../../tmp/screenshots', __dir__))
  end

  # Helper to create a real browser session
  def create_browser(stealth_enabled:, stealth_profile: :maximum)
    config = Crucible::Configuration.new(
      headless: true,
      stealth_enabled: stealth_enabled,
      stealth_profile: stealth_profile,
      timeout: 30
    )
    Crucible::SessionManager.new(config)
  end

  describe 'Intoli Headless Test' do
    let(:test_url) { 'https://intoli.com/blog/not-possible-to-block-chrome-headless/chrome-headless-test.html' }

    it 'passes headless detection tests with stealth enabled' do
      manager = create_browser(stealth_enabled: true)

      begin
        page = manager.page('stealth-test')
        page.go_to(test_url)

        # Wait for tests to complete
        sleep 3

        # Take screenshot for reference
        screenshot_path = File.join(screenshot_dir, 'intoli-stealth.png')
        page.screenshot(path: screenshot_path, full_page: true)

        # Extract test results from the page
        # The Intoli page uses background colors to indicate pass/fail:
        # - Green (lightgreen/palegreen): passed
        # - Red (lightcoral/salmon): failed
        results = page.evaluate(<<~JS)
          (function() {
            var rows = document.querySelectorAll('table tr');
            var results = [];
            for (var i = 1; i < rows.length; i++) {
              var cells = rows[i].querySelectorAll('td');
              if (cells.length >= 2) {
                var text = cells[1].textContent.toLowerCase();
                var style = window.getComputedStyle(cells[1]);
                var bgColor = style.backgroundColor;
                // Parse RGB values from backgroundColor like "rgb(144, 238, 144)"
                var rgb = bgColor.match(/rgb\\((\\d+),\\s*(\\d+),\\s*(\\d+)\\)/);
                var isGreen = false;
                var isRed = false;
                if (rgb) {
                  var r = parseInt(rgb[1]), g = parseInt(rgb[2]), b = parseInt(rgb[3]);
                  // Green: high green component, lower red
                  isGreen = g > 200 && g > r;
                  // Red: high red component, lower green
                  isRed = r > 200 && r > g;
                }
                // Also check for explicit "(passed)" or "(failed)" text
                var textPass = text.indexOf('passed') >= 0;
                var textFail = text.indexOf('failed') >= 0;
                var passed = textPass || (isGreen && !isRed && !textFail);
                results.push({
                  test: cells[0].textContent.trim(),
                  result: cells[1].textContent.trim(),
                  bgColor: bgColor,
                  passed: passed
                });
              }
            }
            return results;
          })();
        JS

        # Log results for debugging

        results.each do |r|
          r['passed'] ? 'PASS' : 'FAIL'
        end

        # Key tests that should pass with stealth
        webdriver_test = results.find { |r| r['test'].downcase.include?('webdriver') }

        if webdriver_test
          expect(webdriver_test['passed']).to be(true),
                                              'WebDriver test failed - navigator.webdriver not hidden'
        end

        # User Agent should pass (not show HeadlessChrome)
        ua_test = results.find { |r| r['test'].downcase.include?('user agent') }
        if ua_test
          expect(ua_test['passed']).to be(true),
                                       'User Agent test failed - still detected as headless'
        end
      ensure
        manager.close_all
      end
    end
  end

  describe 'SannySoft Bot Detection' do
    let(:test_url) { 'https://bot.sannysoft.com/' }

    it 'passes critical bot detection tests with stealth enabled' do
      manager = create_browser(stealth_enabled: true, stealth_profile: :maximum)

      begin
        page = manager.page('sannysoft-stealth')
        page.go_to(test_url)

        # Wait for all tests to complete
        sleep 5

        # Take screenshot for reference
        screenshot_path = File.join(screenshot_dir, 'sannysoft-stealth.png')
        page.screenshot(path: screenshot_path, full_page: true)

        # Check critical evasions directly
        webdriver = page.evaluate('navigator.webdriver')
        user_agent = page.evaluate('navigator.userAgent')
        page.evaluate('navigator.plugins.length')
        languages = page.evaluate('navigator.languages')

        # WebDriver should be false/undefined with stealth
        expect(webdriver).to be_falsey,
                             "navigator.webdriver should be false/undefined with stealth, got: #{webdriver.inspect}"

        # User-Agent should NOT contain Headless
        expect(user_agent).not_to include('Headless'),
                                  "User-Agent should not contain 'Headless' with stealth"

        # Should have languages set
        expect(languages).to be_an(Array)
        expect(languages).not_to be_empty
      ensure
        manager.close_all
      end
    end
  end

  describe 'Stealth vs Vanilla Comparison' do
    it 'shows navigator.webdriver difference' do
      # Test with stealth
      stealth_manager = create_browser(stealth_enabled: true)
      begin
        stealth_page = stealth_manager.page('stealth')
        stealth_page.go_to('about:blank')
        sleep 1
        stealth_webdriver = stealth_page.evaluate('navigator.webdriver')
        stealth_page.evaluate('navigator.userAgent')
      ensure
        stealth_manager.close_all
      end

      # Test without stealth
      vanilla_manager = create_browser(stealth_enabled: false)
      begin
        vanilla_page = vanilla_manager.page('vanilla')
        vanilla_page.go_to('about:blank')
        sleep 1
        vanilla_page.evaluate('navigator.webdriver')
        vanilla_page.evaluate('navigator.userAgent')
      ensure
        vanilla_manager.close_all
      end

      # With stealth, webdriver should be false/undefined
      expect(stealth_webdriver).to be_falsey

      # Without stealth, webdriver is typically true in headless mode
      # (though newer Chrome versions may vary)
    end
  end

  describe 'Evasion Verification' do
    it 'verifies window dimensions are set' do
      manager = create_browser(stealth_enabled: true, stealth_profile: :maximum)

      begin
        page = manager.page('evasion-test')
        page.go_to('about:blank')
        sleep 1

        # Test window dimensions (should be set even in headless)
        outer_width = page.evaluate('window.outerWidth')
        outer_height = page.evaluate('window.outerHeight')

        expect(outer_width).to be > 0, 'window.outerWidth should be set'
        expect(outer_height).to be > 0, 'window.outerHeight should be set'
      ensure
        manager.close_all
      end
    end
  end
end
