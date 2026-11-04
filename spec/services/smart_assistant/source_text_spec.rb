# Custom (MyDesk)
require 'rails_helper'

RSpec.describe SmartAssistant::SourceText do
  let(:account) { create(:account) }
  let(:assistant) { SmartAssistant.for_account(account).tap(&:save!) }

  def text_of(source) = described_class.new(source: source).perform

  it 'keeps a page title and its readable text, without navigation, footer or scripts, and each line once' do
    html = <<~HTML
      <html><head><title> Shop policy </title><script>track()</script></head>
      <body><nav><li>Home</li></nav><h1>Returns</h1><p>Within 14 days.</p><p>Within 14 days.</p>
      <footer><p>© Shop</p></footer></body></html>
    HTML
    allow(SafeFetch).to receive(:fetch) { |*_args, &block| block.call(Struct.new(:tempfile).new(StringIO.new(html))) }
    source = assistant.sources.create!(kind: :website, title: 'Shop', url: 'https://shop.example.com/policy')

    expect(text_of(source)).to eq("Shop policy\nReturns\nWithin 14 days.")
  end

  it 'reads a text document without its byte order mark' do
    source = assistant.sources.create!(kind: :document, title: 'Guide',
                                       file: { io: StringIO.new("\uFEFFالتوصيل خلال يومين"), filename: 'guide.txt',
                                               content_type: 'text/plain' })

    expect(text_of(source)).to eq('التوصيل خلال يومين')
  end

  it 'asks the model for the text of a PDF' do
    client = instance_double(SmartAssistant::LlmClient, extract_text: 'PDF text')
    allow(SmartAssistant::LlmClient).to receive(:new).with(account: account, kind: :knowledge).and_return(client)
    source = assistant.sources.create!(kind: :document, title: 'Catalog',
                                       file: { io: StringIO.new('%PDF-1.4'), filename: 'catalog.pdf', content_type: 'application/pdf' })

    expect(text_of(source)).to eq('PDF text')
    expect(client).to have_received(:extract_text).with(anything, described_class::PDF_PROMPT)
  end

  it 'joins a question and its answer' do
    source = assistant.sources.create!(kind: :faq, title: 'Delivery?', content: 'Two days')

    expect(text_of(source)).to eq("Delivery?\nTwo days")
  end
end
