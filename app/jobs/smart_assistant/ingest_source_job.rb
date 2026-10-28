# Custom (MyDesk): reads a knowledge source, splits it into overlapping passages and embeds them, replacing
# the passages of the previous sync
class SmartAssistant::IngestSourceJob < ApplicationJob
  queue_as :low

  CHUNK_SIZE = 1200
  CHUNK_OVERLAP = 150

  def perform(source_id)
    source = SmartAssistant::Source.find_by(id: source_id)
    return unless source

    source.processing!
    text = SmartAssistant::SourceText.new(source: source).perform
    raise ArgumentError, I18n.t('smart_assistant.errors.no_text') if text.blank?

    store_chunks(source, text)
  rescue StandardError => e
    source&.update!(status: :failed, error_message: e.message.truncate(250))
    ChatwootExceptionTracker.new(e, account: source&.account).capture_exception
  end

  private

  def store_chunks(source, text)
    passages = split(text)
    vectors = SmartAssistant::LlmClient.new(account: source.account, kind: :knowledge).embed(passages)
    now = Time.current
    rows = passages.zip(vectors).map do |content, embedding|
      { account_id: source.account_id, smart_assistant_source_id: source.id, content: content, embedding: embedding,
        created_at: now, updated_at: now }
    end

    SmartAssistant::Source.transaction do
      source.chunks.delete_all
      # One insert for every passage; the rows are built here and have nothing to validate
      SmartAssistant::Chunk.insert_all!(rows) # rubocop:disable Rails/SkipsModelValidations
      source.update!(status: :ready, error_message: nil, chunks_count: rows.size, synced_at: now,
                     content: source.text? || source.faq? ? source.content : text)
    end
  end

  # Packs paragraphs into passages of about CHUNK_SIZE characters; a longer paragraph is cut with overlap
  def split(text)
    paragraphs = text.split(/\n{2,}|\n/).map(&:strip).compact_blank
    paragraphs.flat_map { |paragraph| cut(paragraph) }.each_with_object([]) do |piece, passages|
      if passages.last && passages.last.length + piece.length < CHUNK_SIZE
        passages.last << "\n" << piece
      else
        passages << piece.dup
      end
    end
  end

  def cut(paragraph)
    return [paragraph] if paragraph.length <= CHUNK_SIZE

    (0...paragraph.length).step(CHUNK_SIZE - CHUNK_OVERLAP).map { |start| paragraph[start, CHUNK_SIZE] }
  end
end
