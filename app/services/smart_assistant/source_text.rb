# Custom (MyDesk): the plain text of a knowledge source, ready to be split and embedded
class SmartAssistant::SourceText
  WEBSITE_MAX_BYTES = 5.megabytes
  WEBSITE_CONTENT_TYPES = %w[text/html application/xhtml+xml text/plain].freeze
  NOISE_SELECTORS = 'script, style, noscript, svg, iframe, nav, footer, header, form'.freeze
  PDF_PROMPT = 'Return the full text of this document exactly as written, in its original language. ' \
               'Keep headings, lists and tables as plain text. Return only the text.'.freeze

  pattr_initialize [:source!]

  def perform
    case source.kind
    when 'faq' then "#{source.title}\n#{source.content}"
    when 'text' then source.content
    when 'website' then website_text
    when 'document' then document_text
    end.to_s.strip.first(SmartAssistant::Source::MAX_CONTENT_LENGTH)
  end

  private

  def website_text
    html = SafeFetch.fetch(source.url, max_bytes: WEBSITE_MAX_BYTES, allowed_content_type_prefixes: [],
                                       allowed_content_types: WEBSITE_CONTENT_TYPES) { |result| result.tempfile.read }
    document = Nokogiri::HTML(html.force_encoding(Encoding::UTF_8))
    document.css(NOISE_SELECTORS).remove
    page_title = document.at('title')&.text.to_s.squish
    body = document.at('body') || document
    [page_title, body.css('h1, h2, h3, h4, p, li, td, th, dt, dd').map { |node| node.text.squish }.compact_blank.uniq]
      .flatten.compact_blank.join("\n")
  end

  def document_text
    source.file.blob.open do |file|
      if source.file.blob.content_type == 'application/pdf'
        next SmartAssistant::LlmClient.new(account: source.account, kind: :knowledge).extract_text(file.path, PDF_PROMPT)
      end

      File.read(file.path, encoding: 'bom|utf-8')
    end
  end
end
