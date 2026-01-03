# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Tools::Extraction do
  let(:config) { Crucible::Configuration.new }
  let(:session_manager) { instance_double(Crucible::SessionManager) }
  let(:page) { instance_double(Ferrum::Page) }
  let(:element) { instance_double(Ferrum::Node) }

  before do
    allow(session_manager).to receive(:page).and_return(page)
  end

  describe '.tools' do
    subject(:tools) { described_class.tools(session_manager, config) }

    it 'returns an array of tool classes' do
      expect(tools).to be_an(Array)
      expect(tools).to all(be_a(Class))
    end

    it 'returns 6 extraction tools' do
      expect(tools.size).to eq(6)
    end

    it 'includes expected tool names' do
      tool_names = tools.map(&:name_value)
      expect(tool_names).to contain_exactly(
        'screenshot', 'get_content', 'pdf', 'evaluate', 'get_url', 'get_title'
      )
    end
  end

  describe 'screenshot tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'screenshot' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:selector)
      expect(schema.properties).to have_key(:full_page)
      expect(schema.properties).to have_key(:format)
      expect(schema.properties).to have_key(:quality)
    end

    it 'takes viewport screenshot' do
      allow(page).to receive(:screenshot).and_return('base64data')

      result = call_tool(tool)

      expect(result.content.first[:type]).to eq('image')
      expect(result.content.first[:data]).to eq('base64data')
      expect(result.content.first[:mimeType]).to eq('image/png')
    end

    it 'takes full page screenshot' do
      allow(page).to receive(:screenshot).and_return('base64data')

      call_tool(tool, full_page: true)

      expect(page).to have_received(:screenshot).with(hash_including(full: true))
    end

    it 'supports jpeg format' do
      allow(page).to receive(:screenshot).and_return('base64data')

      result = call_tool(tool, format: 'jpeg')

      expect(result.content.first[:mimeType]).to eq('image/jpeg')
      expect(page).to have_received(:screenshot).with(hash_including(format: :jpeg))
    end
  end

  describe 'get_content tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'get_content' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:selector)
      expect(schema.properties).to have_key(:format)
    end

    it 'gets full page HTML' do
      allow(page).to receive(:body).and_return('<html><body>Hello</body></html>')

      result = call_tool(tool)

      expect(result.content.first[:text]).to include('<html>')
    end

    it 'gets page text' do
      body_element = double('body')
      allow(page).to receive(:at_css).with('body').and_return(body_element)
      allow(body_element).to receive(:text).and_return('Hello World')

      result = call_tool(tool, format: 'text')

      expect(result.content.first[:text]).to eq('Hello World')
    end

    it 'gets element content' do
      allow(page).to receive(:at_css).with('.content').and_return(element)
      allow(element).to receive(:property).with('outerHTML').and_return('<div>Content</div>')

      result = call_tool(tool, selector: '.content')

      expect(result.content.first[:text]).to eq('<div>Content</div>')
    end
  end

  describe 'pdf tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'pdf' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:landscape)
      expect(schema.properties).to have_key(:format)
      expect(schema.properties).to have_key(:scale)
    end

    it 'generates PDF' do
      allow(page).to receive(:pdf).and_return('pdfbase64')

      result = call_tool(tool)

      expect(result.content.first[:type]).to eq('resource')
      expect(result.content.first[:resource][:mimeType]).to eq('application/pdf')
    end

    it 'supports landscape orientation' do
      allow(page).to receive(:pdf).and_return('pdfbase64')

      call_tool(tool, landscape: true)

      expect(page).to have_received(:pdf).with(hash_including(landscape: true))
    end
  end

  describe 'evaluate tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'evaluate' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:expression)
      expect(schema.required).to include(:expression)
    end

    it 'evaluates JavaScript expression' do
      allow(page).to receive(:evaluate).with('1 + 1').and_return(2)

      result = call_tool(tool, expression: '1 + 1')

      expect(result.content.first[:text]).to eq('2')
    end

    it 'returns null for nil results' do
      allow(page).to receive(:evaluate).and_return(nil)

      result = call_tool(tool, expression: 'void 0')

      expect(result.content.first[:text]).to eq('null')
    end

    it 'handles JavaScript errors' do
      allow(page).to receive(:evaluate).and_raise(Ferrum::JavaScriptError.new({ 'message' => 'Syntax error' }))

      result = call_tool(tool, expression: 'invalid{')

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('JavaScript error')
    end
  end

  describe 'get_url tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'get_url' } }

    it 'returns current URL' do
      allow(page).to receive(:current_url).and_return('https://example.com/page')

      result = call_tool(tool)

      expect(result.content.first[:text]).to eq('https://example.com/page')
    end
  end

  describe 'get_title tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'get_title' } }

    it 'returns page title' do
      allow(page).to receive(:current_title).and_return('Example Page')

      result = call_tool(tool)

      expect(result.content.first[:text]).to eq('Example Page')
    end

    it 'returns empty string for nil title' do
      allow(page).to receive(:current_title).and_return(nil)

      result = call_tool(tool)

      expect(result.content.first[:text]).to eq('')
    end
  end
end
