# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Tools::Cookies do
  let(:config) { Crucible::Configuration.new }
  let(:session_manager) { instance_double(Crucible::SessionManager) }
  let(:page) { instance_double(Ferrum::Page) }
  let(:cookies) { instance_double(Ferrum::Cookies) }

  before do
    allow(session_manager).to receive(:page).and_return(page)
    allow(page).to receive(:cookies).and_return(cookies)
  end

  describe '.tools' do
    subject(:tools) { described_class.tools(session_manager, config) }

    it 'returns an array of tool classes' do
      expect(tools).to be_an(Array)
      expect(tools).to all(be_a(Class))
    end

    it 'returns 3 cookie tools' do
      expect(tools.size).to eq(3)
    end

    it 'includes expected tool names' do
      tool_names = tools.map(&:name_value)
      expect(tool_names).to contain_exactly(
        'get_cookies', 'set_cookies', 'clear_cookies'
      )
    end
  end

  describe 'get_cookies tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'get_cookies' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:session)
      expect(schema.properties).to have_key(:name)
    end

    it 'returns all cookies' do
      cookie = double('cookie',
                      name: 'session_id',
                      value: 'abc123',
                      domain: 'example.com',
                      path: '/',
                      secure?: true,
                      httponly?: false,
                      samesite: 'Lax',
                      expires: nil)
      allow(cookies).to receive(:all).and_return({ 'session_id' => cookie })

      result = call_tool(tool)

      parsed = JSON.parse(result.content.first[:text])
      expect(parsed).to be_an(Array)
      expect(parsed.first['name']).to eq('session_id')
      expect(parsed.first['value']).to eq('abc123')
    end

    it 'returns specific cookie by name' do
      cookie = double('cookie',
                      name: 'token',
                      value: 'xyz',
                      domain: 'example.com',
                      path: '/',
                      secure?: false,
                      httponly?: true,
                      samesite: nil,
                      expires: nil)
      allow(cookies).to receive(:[]).with('token').and_return(cookie)

      result = call_tool(tool, name: 'token')

      parsed = JSON.parse(result.content.first[:text])
      expect(parsed.first['name']).to eq('token')
    end

    it 'returns empty array for missing cookie' do
      allow(cookies).to receive(:[]).with('missing').and_return(nil)

      result = call_tool(tool, name: 'missing')

      parsed = JSON.parse(result.content.first[:text])
      expect(parsed).to eq([])
    end
  end

  describe 'set_cookies tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'set_cookies' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:cookies)
      expect(schema.required).to include(:cookies)
    end

    it 'sets a cookie' do
      allow(cookies).to receive(:set)

      result = call_tool(tool, cookies: [{ name: 'token', value: 'abc123' }])

      expect(cookies).to have_received(:set).with(hash_including(name: 'token', value: 'abc123'))
      expect(result.content.first[:text]).to include('Set 1 cookie(s)')
    end

    it 'sets multiple cookies' do
      allow(cookies).to receive(:set)

      result = call_tool(tool, cookies: [
                           { name: 'a', value: '1' },
                           { name: 'b', value: '2' }
                         ])

      expect(cookies).to have_received(:set).twice
      expect(result.content.first[:text]).to include('Set 2 cookie(s)')
    end

    it 'sets cookie with all options' do
      allow(cookies).to receive(:set)

      call_tool(tool, cookies: [{
                  name: 'secure_cookie',
                  value: 'secret',
                  domain: 'example.com',
                  path: '/api',
                  secure: true,
                  httpOnly: true,
                  sameSite: 'Strict'
                }])

      expect(cookies).to have_received(:set).with(
        name: 'secure_cookie',
        value: 'secret',
        domain: 'example.com',
        path: '/api',
        secure: true,
        httponly: true,
        samesite: 'Strict'
      )
    end
  end

  describe 'clear_cookies tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'clear_cookies' } }

    it 'clears all cookies' do
      allow(cookies).to receive(:clear)

      result = call_tool(tool)

      expect(cookies).to have_received(:clear)
      expect(result.content.first[:text]).to include('Cleared all cookies')
    end

    it 'clears specific cookie by name' do
      allow(page).to receive(:current_url).and_return('https://example.com/page')
      allow(cookies).to receive(:remove)

      result = call_tool(tool, name: 'session_id')

      expect(cookies).to have_received(:remove).with(name: 'session_id', url: 'https://example.com/page')
      expect(result.content.first[:text]).to include('Cleared cookie: session_id')
    end
  end
end
