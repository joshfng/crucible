# frozen_string_literal: true

require 'tempfile'

RSpec.describe Crucible::Configuration do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'has sensible default values' do
      expect(config.headless).to be(true)
      expect(config.viewport_width).to eq(1280)
      expect(config.viewport_height).to eq(720)
      expect(config.chrome_path).to be_nil
      expect(config.timeout).to eq(30)
      expect(config.error_level).to eq(:warn)
      expect(config.screenshot_format).to eq(:png)
      expect(config.content_format).to eq(:html)
    end

    it 'has stealth defaults' do
      expect(config.stealth_enabled).to be(true)
      expect(config.stealth_profile).to eq(:moderate)
      expect(config.stealth_locale).to eq('en-US,en')
    end
  end

  describe '#initialize' do
    it 'accepts custom options' do
      config = described_class.new(
        headless: false,
        timeout: 60,
        viewport_width: 1920
      )

      expect(config.headless).to be(false)
      expect(config.timeout).to eq(60)
      expect(config.viewport_width).to eq(1920)
    end

    it 'accepts stealth options' do
      config = described_class.new(
        stealth_enabled: false,
        stealth_profile: :maximum,
        stealth_locale: 'de-DE,de'
      )

      expect(config.stealth_enabled).to be(false)
      expect(config.stealth_profile).to eq(:maximum)
      expect(config.stealth_locale).to eq('de-DE,de')
    end
  end

  describe '#merge' do
    it 'returns a new configuration with merged options' do
      original = described_class.new(timeout: 30)
      merged = original.merge(timeout: 60, headless: false)

      expect(original.timeout).to eq(30)
      expect(merged.timeout).to eq(60)
      expect(merged.headless).to be(false)
    end
  end

  describe '#to_h' do
    it 'returns a hash of all configuration options' do
      hash = config.to_h

      expect(hash).to be_a(Hash)
      expect(hash.keys).to include(:headless, :viewport_width, :timeout)
      expect(hash.keys).to include(:stealth_enabled, :stealth_profile)
    end
  end

  describe '#browser_options' do
    it 'returns options suitable for Ferrum::Browser' do
      config = described_class.new(
        headless: true,
        viewport_width: 1920,
        viewport_height: 1080,
        timeout: 45
      )

      opts = config.browser_options

      expect(opts[:headless]).to be(true)
      expect(opts[:window_size]).to eq([1920, 1080])
      expect(opts[:timeout]).to eq(45)
      expect(opts[:process_timeout]).to eq(90)
    end

    it 'includes chrome_path when set' do
      config = described_class.new(chrome_path: '/usr/bin/chromium')
      expect(config.browser_options[:browser_path]).to eq('/usr/bin/chromium')
    end

    it 'excludes chrome_path when nil' do
      expect(config.browser_options).not_to have_key(:browser_path)
    end
  end

  describe '#stealth' do
    it 'returns a Stealth instance with config settings' do
      config = described_class.new(
        stealth_enabled: true,
        stealth_profile: :maximum,
        stealth_locale: 'fr-FR,fr'
      )

      stealth = config.stealth

      expect(stealth).to be_a(Crucible::Stealth)
      expect(stealth.profile).to eq(:maximum)
      expect(stealth.enabled).to be(true)
      expect(stealth.options[:locale]).to eq('fr-FR,fr')
    end
  end

  describe '#validate!' do
    it 'raises on non-positive timeout' do
      config = described_class.new(timeout: 0)
      expect { config.validate! }.to raise_error(Crucible::Error, /Timeout must be positive/)
    end

    it 'raises on invalid error_level' do
      config = described_class.new(error_level: :invalid)
      expect { config.validate! }.to raise_error(Crucible::Error, /Invalid error_level/)
    end

    it 'raises on invalid screenshot_format' do
      config = described_class.new(screenshot_format: :gif)
      expect { config.validate! }.to raise_error(Crucible::Error, /Invalid screenshot_format/)
    end

    it 'raises on invalid stealth_profile' do
      config = described_class.new(stealth_profile: :invalid)
      expect { config.validate! }.to raise_error(Crucible::Error, /Invalid stealth_profile/)
    end

    it 'returns true for valid configuration' do
      expect(config.validate!).to be(true)
    end
  end

  describe '.from_file' do
    let(:yaml_content) do
      <<~YAML
        browser:
          headless: false
          window_size: [1920, 1080]
          timeout: 60

        stealth:
          enabled: true
          profile: maximum
          locale: "de-DE,de"

        server:
          log_level: debug
      YAML
    end

    it 'loads configuration from YAML file' do
      Tempfile.create(['config', '.yml']) do |f|
        f.write(yaml_content)
        f.close

        config = described_class.from_file(f.path)

        expect(config.headless).to be(false)
        expect(config.viewport_width).to eq(1920)
        expect(config.viewport_height).to eq(1080)
        expect(config.timeout).to eq(60)
        expect(config.stealth_enabled).to be(true)
        expect(config.stealth_profile).to eq(:maximum)
        expect(config.stealth_locale).to eq('de-DE,de')
        expect(config.error_level).to eq(:debug)
      end
    end

    it 'raises for missing file' do
      expect { described_class.from_file('/nonexistent/file.yml') }.to raise_error(
        Crucible::Error,
        /Config file not found/
      )
    end
  end

  describe '#apply_mode' do
    let(:yaml_content) do
      <<~YAML
        stealth:
          profile: moderate

        modes:
          default: ai_agent
          ai_agent:
            stealth_profile: maximum
            screenshot_format: png
          testing:
            stealth_profile: minimal
      YAML
    end

    it 'applies mode settings' do
      Tempfile.create(['config', '.yml']) do |f|
        f.write(yaml_content)
        f.close

        config = described_class.from_file(f.path)
        config.apply_mode(:ai_agent)

        expect(config.stealth_profile).to eq(:maximum)
        expect(config.screenshot_format).to eq(:png)
      end
    end

    it 'returns available modes' do
      Tempfile.create(['config', '.yml']) do |f|
        f.write(yaml_content)
        f.close

        config = described_class.from_file(f.path)

        expect(config.available_modes).to include(:ai_agent)
        expect(config.available_modes).to include(:testing)
      end
    end
  end
end
