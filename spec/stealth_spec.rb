# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Stealth do
  describe '#initialize' do
    it 'creates with default options' do
      stealth = described_class.new

      expect(stealth.profile).to eq(:moderate)
      expect(stealth.enabled).to be(true)
      expect(stealth.options[:locale]).to eq('en-US,en')
    end

    it 'accepts custom profile' do
      stealth = described_class.new(profile: :maximum)

      expect(stealth.profile).to eq(:maximum)
    end

    it 'accepts custom locale' do
      stealth = described_class.new(locale: 'de-DE,de')

      expect(stealth.options[:locale]).to eq('de-DE,de')
    end

    it 'can be disabled' do
      stealth = described_class.new(enabled: false)

      expect(stealth.enabled).to be(false)
    end

    it 'raises for invalid profile' do
      expect { described_class.new(profile: :invalid) }.to raise_error(
        Crucible::Error,
        /Invalid stealth profile/
      )
    end
  end

  describe '#enabled_evasions' do
    it 'returns minimal evasions for minimal profile' do
      stealth = described_class.new(profile: :minimal)

      expect(stealth.enabled_evasions).to include(:navigator_webdriver)
      expect(stealth.enabled_evasions).not_to include(:chrome_runtime)
    end

    it 'returns moderate evasions for moderate profile' do
      stealth = described_class.new(profile: :moderate)

      expect(stealth.enabled_evasions).to include(:navigator_webdriver)
      expect(stealth.enabled_evasions).to include(:chrome_runtime)
      expect(stealth.enabled_evasions).not_to include(:navigator_plugins)
    end

    it 'returns all evasions for maximum profile' do
      stealth = described_class.new(profile: :maximum)

      expect(stealth.enabled_evasions).to include(:navigator_webdriver)
      expect(stealth.enabled_evasions).to include(:chrome_runtime)
      expect(stealth.enabled_evasions).to include(:navigator_plugins)
      expect(stealth.enabled_evasions).to include(:webgl_vendor)
    end
  end

  describe '#extensions' do
    it 'returns empty array when disabled' do
      stealth = described_class.new(enabled: false)

      expect(stealth.extensions).to eq([])
    end

    it 'returns scripts when enabled' do
      stealth = described_class.new(profile: :minimal)

      extensions = stealth.extensions
      expect(extensions).not_to be_empty
      expect(extensions.first).to include('_stealthUtils')
    end

    it 'includes utils script by default' do
      stealth = described_class.new(profile: :minimal)

      extensions = stealth.extensions
      expect(extensions.first).to include('_stealthUtils')
    end
  end

  describe 'profiles' do
    it 'defines minimal profile' do
      expect(described_class::PROFILES[:minimal]).to include(:navigator_webdriver)
    end

    it 'defines moderate profile' do
      expect(described_class::PROFILES[:moderate]).to include(:chrome_runtime)
    end

    it 'defines maximum profile' do
      expect(described_class::PROFILES[:maximum]).to include(:navigator_plugins)
    end
  end
end
