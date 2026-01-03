# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Tools::Stealth do
  let(:config) { Crucible::Configuration.new }
  let(:session_manager) { instance_double(Crucible::SessionManager) }

  describe '.tools' do
    subject(:tools) { described_class.tools(session_manager, config) }

    it 'returns an array of tool classes' do
      expect(tools).to be_an(Array)
      expect(tools).to all(be_a(Class))
    end

    it 'returns 4 stealth tools' do
      expect(tools.size).to eq(4)
    end

    it 'includes expected tool names' do
      tool_names = tools.map(&:name_value)
      expect(tool_names).to contain_exactly(
        'enable_stealth', 'disable_stealth', 'get_stealth_status', 'set_stealth_profile'
      )
    end
  end

  describe 'enable_stealth tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'enable_stealth' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:session)
      expect(schema.properties).to have_key(:profile)
    end

    it 'enables stealth with default session' do
      allow(session_manager).to receive(:enable_stealth).with('default', profile: nil)
      allow(session_manager).to receive(:stealth_info).with('default').and_return({ enabled: true, profile: :moderate })

      result = call_tool(tool)

      expect(session_manager).to have_received(:enable_stealth).with('default', profile: nil)
      expect(result.content.first[:text]).to include("Stealth mode enabled for session 'default'")
      expect(result.content.first[:text]).to include('moderate')
    end

    it 'enables stealth with specified profile' do
      allow(session_manager).to receive(:enable_stealth).with('default', profile: :maximum)
      allow(session_manager).to receive(:stealth_info).with('default').and_return({ enabled: true, profile: :maximum })

      result = call_tool(tool, profile: 'maximum')

      expect(session_manager).to have_received(:enable_stealth).with('default', profile: :maximum)
      expect(result.content.first[:text]).to include('maximum')
    end

    it 'enables stealth for specific session' do
      allow(session_manager).to receive(:enable_stealth).with('my-session', profile: :minimal)
      allow(session_manager).to receive(:stealth_info).with('my-session').and_return({ enabled: true,
                                                                                       profile: :minimal })

      result = call_tool(tool, session: 'my-session', profile: 'minimal')

      expect(session_manager).to have_received(:enable_stealth).with('my-session', profile: :minimal)
      expect(result.content.first[:text]).to include("session 'my-session'")
    end

    it 'returns error for non-existent session' do
      allow(session_manager).to receive(:enable_stealth).and_raise(Crucible::SessionNotFoundError.new('missing'))

      result = call_tool(tool, session: 'missing')

      expect(result.error?).to be(true)
    end
  end

  describe 'disable_stealth tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'disable_stealth' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:session)
    end

    it 'disables stealth with default session' do
      allow(session_manager).to receive(:disable_stealth).with('default')

      result = call_tool(tool)

      expect(session_manager).to have_received(:disable_stealth).with('default')
      expect(result.content.first[:text]).to include("Stealth mode disabled for session 'default'")
    end

    it 'disables stealth for specific session' do
      allow(session_manager).to receive(:disable_stealth).with('my-session')

      result = call_tool(tool, session: 'my-session')

      expect(session_manager).to have_received(:disable_stealth).with('my-session')
      expect(result.content.first[:text]).to include("session 'my-session'")
    end

    it 'returns error for non-existent session' do
      allow(session_manager).to receive(:disable_stealth).and_raise(Crucible::SessionNotFoundError.new('missing'))

      result = call_tool(tool, session: 'missing')

      expect(result.error?).to be(true)
    end
  end

  describe 'get_stealth_status tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'get_stealth_status' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:session)
    end

    it 'returns stealth status' do
      allow(session_manager).to receive(:stealth_info).with('default').and_return({
                                                                                    enabled: true,
                                                                                    profile: :moderate
                                                                                  })

      result = call_tool(tool)

      parsed = JSON.parse(result.content.first[:text])
      expect(parsed['session']).to eq('default')
      expect(parsed['stealth_enabled']).to be(true)
      expect(parsed['profile']).to eq('moderate')
    end

    it 'returns status for specific session' do
      allow(session_manager).to receive(:stealth_info).with('my-session').and_return({
                                                                                       enabled: false,
                                                                                       profile: :minimal
                                                                                     })

      result = call_tool(tool, session: 'my-session')

      parsed = JSON.parse(result.content.first[:text])
      expect(parsed['session']).to eq('my-session')
      expect(parsed['stealth_enabled']).to be(false)
    end

    it 'returns error for non-existent session' do
      allow(session_manager).to receive(:stealth_info).and_raise(Crucible::SessionNotFoundError.new('missing'))

      result = call_tool(tool, session: 'missing')

      expect(result.error?).to be(true)
    end
  end

  describe 'set_stealth_profile tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'set_stealth_profile' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:session)
      expect(schema.properties).to have_key(:profile)
      expect(schema.required).to include(:profile)
    end

    it 'sets stealth profile' do
      allow(session_manager).to receive(:enable_stealth).with('default', profile: :maximum)

      result = call_tool(tool, profile: 'maximum')

      expect(session_manager).to have_received(:enable_stealth).with('default', profile: :maximum)
      expect(result.content.first[:text]).to include("Stealth profile set to 'maximum'")
    end

    it 'sets profile for specific session' do
      allow(session_manager).to receive(:enable_stealth).with('my-session', profile: :minimal)

      result = call_tool(tool, session: 'my-session', profile: 'minimal')

      expect(session_manager).to have_received(:enable_stealth).with('my-session', profile: :minimal)
      expect(result.content.first[:text]).to include("session 'my-session'")
    end

    it 'returns error for invalid profile' do
      result = call_tool(tool, profile: 'invalid')

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('Invalid profile')
    end

    it 'returns error for non-existent session' do
      allow(session_manager).to receive(:enable_stealth).and_raise(Crucible::SessionNotFoundError.new('missing'))

      result = call_tool(tool, session: 'missing', profile: 'moderate')

      expect(result.error?).to be(true)
    end
  end
end
