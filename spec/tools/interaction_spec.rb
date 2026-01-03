# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Crucible::Tools::Interaction do
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

    it 'returns 6 interaction tools' do
      expect(tools.size).to eq(6)
    end

    it 'includes expected tool names' do
      tool_names = tools.map(&:name_value)
      expect(tool_names).to contain_exactly(
        'click', 'type', 'fill_form', 'select_option', 'scroll', 'hover'
      )
    end
  end

  describe 'click tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'click' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:selector)
      expect(schema.properties).to have_key(:button)
      expect(schema.properties).to have_key(:count)
      expect(schema.required).to include(:selector)
    end

    it 'clicks element successfully' do
      allow(page).to receive(:at_css).with('#btn').and_return(element)
      allow(element).to receive(:click)

      result = call_tool(tool, selector: '#btn')

      expect(result.content.first[:text]).to include('Clicked')
      expect(element).to have_received(:click).with(mode: :left)
    end

    it 'supports double click' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:click)

      call_tool(tool, selector: '#btn', count: 2)

      expect(element).to have_received(:click).with(mode: :double)
    end

    it 'returns error when element not found' do
      allow(page).to receive(:at_css).and_return(nil)

      result = call_tool(tool, selector: '#missing')

      expect(result.error?).to be(true)
      expect(result.content.first[:text]).to include('Element not found')
    end
  end

  describe 'type tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'type' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:selector)
      expect(schema.properties).to have_key(:text)
      expect(schema.properties).to have_key(:clear)
      expect(schema.properties).to have_key(:submit)
      expect(schema.required).to include(:selector, :text)
    end

    it 'types text into element' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:focus)
      allow(element).to receive(:type)

      result = call_tool(tool, selector: '#input', text: 'hello')

      expect(result.content.first[:text]).to include('Typed into')
      expect(element).to have_received(:type).with('hello')
    end

    it 'clears field before typing when clear: true' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:focus)
      allow(element).to receive(:type)

      call_tool(tool, selector: '#input', text: 'hello', clear: true)

      # Should call type twice - once to clear, once to type
      expect(element).to have_received(:type).twice
    end

    it 'submits when submit: true' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:focus)
      allow(element).to receive(:type)

      call_tool(tool, selector: '#input', text: 'hello', submit: true)

      expect(element).to have_received(:type).with('hello', :Enter)
    end
  end

  describe 'fill_form tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'fill_form' } }

    it 'has correct schema' do
      schema = tool.input_schema_value
      expect(schema.properties).to have_key(:fields)
      expect(schema.required).to include(:fields)
    end

    it 'fills multiple fields' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:focus)
      allow(element).to receive(:type)

      result = call_tool(tool, fields: [
                           { selector: '#email', value: 'test@example.com' },
                           { selector: '#name', value: 'John' }
                         ])

      expect(result.content.first[:text]).to include('Filled 2 field(s)')
    end

    it 'reports fields not found' do
      allow(page).to receive(:at_css).with('#found').and_return(element)
      allow(page).to receive(:at_css).with('#missing').and_return(nil)
      allow(element).to receive(:focus)
      allow(element).to receive(:type)

      result = call_tool(tool, fields: [
                           { selector: '#found', value: 'value' },
                           { selector: '#missing', value: 'value' }
                         ])

      expect(result.content.first[:text]).to include('Filled 1 field(s)')
      expect(result.content.first[:text]).to include('Not found: #missing')
    end
  end

  describe 'scroll tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'scroll' } }

    it 'scrolls element into view' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:scroll_into_view)

      result = call_tool(tool, selector: '#target')

      expect(result.content.first[:text]).to include('Scrolled into view')
      expect(element).to have_received(:scroll_into_view)
    end

    it 'scrolls by direction' do
      allow(page).to receive(:execute)

      result = call_tool(tool, direction: 'down')

      expect(result.content.first[:text]).to include('Scrolled by')
      expect(page).to have_received(:execute).with('window.scrollBy(0, 500)')
    end

    it 'scrolls by coordinates' do
      allow(page).to receive(:execute)

      call_tool(tool, x: 100, y: 200)

      expect(page).to have_received(:execute).with('window.scrollBy(100, 200)')
    end
  end

  describe 'hover tool' do
    subject(:tool) { described_class.tools(session_manager, config).find { |t| t.name_value == 'hover' } }

    it 'hovers over element' do
      allow(page).to receive(:at_css).and_return(element)
      allow(element).to receive(:hover)

      result = call_tool(tool, selector: '#menu')

      expect(result.content.first[:text]).to include('Hovering over')
      expect(element).to have_received(:hover)
    end
  end
end
