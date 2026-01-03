# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Tools::Sessions do
  let(:config) { Crucible::Configuration.new }
  let(:session_manager) { instance_double(Crucible::SessionManager) }

  describe '.tools' do
    subject(:tools) { described_class.tools(session_manager, config) }

    it 'returns an array of tool classes' do
      expect(tools).to be_an(Array)
      expect(tools).to all(be_a(Class))
    end

    it 'returns 2 session tools' do
      expect(tools.size).to eq(2)
    end

    it 'includes expected tool names' do
      tool_names = tools.map(&:name_value)
      expect(tool_names).to contain_exactly(
        'list_sessions', 'close_session'
      )
    end
  end

  describe 'list_sessions tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'list_sessions' } }

    it 'lists no active sessions' do
      allow(session_manager).to receive(:list).and_return([])

      result = call_tool(tool)

      expect(result.content.first[:text]).to include('No active sessions')
    end

    it 'lists active sessions' do
      allow(session_manager).to receive(:list).and_return(%w[default scraper login-test])

      result = call_tool(tool)

      parsed = JSON.parse(result.content.first[:text])
      expect(parsed['count']).to eq(3)
      expect(parsed['sessions']).to contain_exactly('default', 'scraper', 'login-test')
    end
  end

  describe 'close_session tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'close_session' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:session)
      expect(schema.properties).to have_key(:all)
    end

    it 'closes specific session' do
      allow(session_manager).to receive(:close).with('my-session').and_return(true)

      result = call_tool(tool, session: 'my-session')

      expect(result.content.first[:text]).to include('Closed session: my-session')
    end

    it 'returns error for non-existent session' do
      allow(session_manager).to receive(:close).with('missing').and_return(false)

      result = call_tool(tool, session: 'missing')

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('Session not found')
    end

    it 'closes all sessions' do
      allow(session_manager).to receive(:count).and_return(3)
      allow(session_manager).to receive(:close_all)

      result = call_tool(tool, all: true)

      expect(session_manager).to have_received(:close_all)
      expect(result.content.first[:text]).to include('Closed 3 session(s)')
    end

    it 'requires session name or all flag' do
      result = call_tool(tool)

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('specify a session name')
    end
  end
end
