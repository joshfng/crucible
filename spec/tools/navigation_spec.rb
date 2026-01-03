# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Tools::Navigation do
  let(:config) { Crucible::Configuration.new }
  let(:session_manager) { instance_double(Crucible::SessionManager) }
  let(:page) { instance_double(Ferrum::Page) }

  before do
    allow(session_manager).to receive(:page).and_return(page)
  end

  describe '.tools' do
    subject(:tools) { described_class.tools(session_manager, config) }

    it 'returns an array of tool classes' do
      expect(tools).to be_an(Array)
      expect(tools).to all(be_a(Class))
    end

    it 'returns 5 navigation tools' do
      expect(tools.size).to eq(5)
    end

    it 'includes expected tool names' do
      tool_names = tools.map(&:name_value)
      expect(tool_names).to contain_exactly(
        'navigate', 'wait_for', 'back', 'forward', 'refresh'
      )
    end
  end

  describe 'navigate tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'navigate' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.to_h[:type]).to eq('object')
      expect(schema.properties).to have_key(:url)
      expect(schema.required).to include(:url)
    end

    it 'navigates to url successfully' do
      allow(page).to receive(:go_to).with('https://example.com')

      result = call_tool(tool, url: 'https://example.com')

      expect(result).to be_a(MCP::Tool::Response)
      expect(result.content.first[:text]).to include('Navigated to https://example.com')
      expect(page).to have_received(:go_to).with('https://example.com')
    end

    it 'uses specified session' do
      allow(page).to receive(:go_to)

      call_tool(tool, session: 'my-session', url: 'https://example.com')

      expect(session_manager).to have_received(:page).with('my-session')
    end

    it 'returns error on failure' do
      allow(page).to receive(:go_to).and_raise(Ferrum::Error.new('Connection refused'))

      result = call_tool(tool, url: 'https://example.com')

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('Navigation failed')
    end
  end

  describe 'wait_for tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'wait_for' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:selector)
      expect(schema.properties).to have_key(:timeout)
      expect(schema.required).to include(:selector)
    end

    it 'waits for element successfully' do
      element = double('element')
      allow(page).to receive(:at_css).with('.content').and_return(element)

      result = call_tool(tool, selector: '.content')

      expect(result.content.first[:text]).to include('Found element')
    end

    it 'returns error when element not found' do
      allow(page).to receive(:at_css).and_return(nil)

      result = call_tool(tool, selector: '.missing', timeout: 0.1)

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('Timeout')
    end
  end

  describe 'back tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'back' } }

    it 'navigates back' do
      allow(page).to receive(:back)

      result = call_tool(tool)

      expect(result.content.first[:text]).to include('Navigated back')
      expect(page).to have_received(:back)
    end
  end

  describe 'forward tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'forward' } }

    it 'navigates forward' do
      allow(page).to receive(:forward)

      result = call_tool(tool)

      expect(result.content.first[:text]).to include('Navigated forward')
      expect(page).to have_received(:forward)
    end
  end

  describe 'refresh tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'refresh' } }

    it 'refreshes the page' do
      allow(page).to receive(:refresh)

      result = call_tool(tool)

      expect(result.content.first[:text]).to include('Page refreshed')
      expect(page).to have_received(:refresh)
    end
  end
end
