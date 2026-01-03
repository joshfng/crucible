# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::SessionManager do
  let(:config) { Crucible::Configuration.new(headless: true, timeout: 5, stealth_enabled: false) }
  let(:browser) { instance_double(Ferrum::Browser) }
  let(:page) { instance_double(Ferrum::Page) }

  before do
    allow(Ferrum::Browser).to receive(:new).and_return(browser)
    allow(browser).to receive_messages(page: page, create_page: page)
    allow(browser).to receive(:quit)
  end

  describe '#initialize' do
    it 'creates with configuration' do
      manager = described_class.new(config)
      expect(manager.list).to eq([])
    end
  end

  describe '#get_or_create' do
    subject(:manager) { described_class.new(config) }

    it 'creates a new browser session' do
      result = manager.get_or_create('test')

      expect(result).to eq(browser)
      expect(manager.list).to include('test')
    end

    it 'returns existing session' do
      manager.get_or_create('test')
      result = manager.get_or_create('test')

      expect(result).to eq(browser)
      expect(Ferrum::Browser).to have_received(:new).once
    end

    it 'uses default session name' do
      manager.get_or_create

      expect(manager.list).to include('default')
    end

    it 'passes browser options from config' do
      manager.get_or_create('test')

      expect(Ferrum::Browser).to have_received(:new).with(
        headless: true,
        window_size: [1280, 720],
        timeout: 5,
        process_timeout: 10
      )
    end
  end

  describe '#get' do
    subject(:manager) { described_class.new(config) }

    it 'returns existing session' do
      manager.get_or_create('existing')

      result = manager.get('existing')

      expect(result).to eq(browser)
    end

    it 'raises for non-existent session' do
      expect { manager.get('missing') }.to raise_error(
        Crucible::SessionNotFoundError,
        /Session 'missing' not found/
      )
    end
  end

  describe '#page' do
    subject(:manager) { described_class.new(config) }

    it 'returns page for session' do
      result = manager.page('test')

      expect(result).to eq(page)
    end

    it 'creates session if needed' do
      manager.page('new-session')

      expect(manager.exists?('new-session')).to be(true)
    end
  end

  describe '#create' do
    subject(:manager) { described_class.new(config) }

    it 'creates a new session' do
      result = manager.create('new')

      expect(result).to eq(browser)
      expect(manager.exists?('new')).to be(true)
    end

    it 'raises if session already exists' do
      manager.create('existing')

      expect { manager.create('existing') }.to raise_error(
        Crucible::Error,
        /Session 'existing' already exists/
      )
    end
  end

  describe '#close' do
    subject(:manager) { described_class.new(config) }

    it 'closes existing session' do
      manager.get_or_create('test')

      result = manager.close('test')

      expect(result).to be(true)
      expect(browser).to have_received(:quit)
      expect(manager.exists?('test')).to be(false)
    end

    it 'returns false for non-existent session' do
      result = manager.close('missing')

      expect(result).to be(false)
    end
  end

  describe '#close_all' do
    subject(:manager) { described_class.new(config) }

    it 'closes all sessions' do
      manager.get_or_create('a')
      manager.get_or_create('b')
      manager.get_or_create('c')

      manager.close_all

      expect(manager.list).to eq([])
      expect(browser).to have_received(:quit).exactly(3).times
    end
  end

  describe '#list' do
    subject(:manager) { described_class.new(config) }

    it 'returns session names' do
      manager.get_or_create('alpha')
      manager.get_or_create('beta')

      expect(manager.list).to contain_exactly('alpha', 'beta')
    end
  end

  describe '#exists?' do
    subject(:manager) { described_class.new(config) }

    it 'returns true for existing session' do
      manager.get_or_create('test')

      expect(manager.exists?('test')).to be(true)
    end

    it 'returns false for non-existent session' do
      expect(manager.exists?('missing')).to be(false)
    end
  end

  describe '#count' do
    subject(:manager) { described_class.new(config) }

    it 'returns session count' do
      expect(manager.count).to eq(0)

      manager.get_or_create('a')
      manager.get_or_create('b')

      expect(manager.count).to eq(2)
    end
  end
end
