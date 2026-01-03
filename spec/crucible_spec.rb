# frozen_string_literal: true

RSpec.describe Crucible do
  it 'has a version number' do
    expect(Crucible::VERSION).not_to be_nil
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(described_class.configuration).to be_a(Crucible::Configuration)
    end

    it 'returns the same instance on subsequent calls' do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      described_class.configure do |config|
        config.headless = false
        config.timeout = 60
      end

      expect(described_class.configuration.headless).to be(false)
      expect(described_class.configuration.timeout).to eq(60)
    end
  end

  describe '.reset!' do
    it 'resets the configuration to defaults' do
      described_class.configure { |c| c.timeout = 999 }
      described_class.reset!
      expect(described_class.configuration.timeout).to eq(30)
    end
  end
end
