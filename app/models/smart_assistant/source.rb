# Custom (MyDesk): one piece of the merchant's knowledge base. Saving it queues SmartAssistant::IngestSourceJob,
# which extracts its text, splits it into chunks and embeds them for retrieval.
# == Schema Information
#
# Table name: smart_assistant_sources
#
#  id                 :bigint           not null, primary key
#  chunks_count       :integer          default(0), not null
#  content            :text
#  error_message      :string
#  kind               :integer          not null
#  status             :integer          default("pending"), not null
#  synced_at          :datetime
#  title              :string           not null
#  url                :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  smart_assistant_id :bigint           not null
#
# Indexes
#
#  index_smart_assistant_sources_on_smart_assistant_id  (smart_assistant_id)
#
class SmartAssistant::Source < ApplicationRecord
  MAX_CONTENT_LENGTH = 100_000
  MAX_FILE_SIZE = 10.megabytes
  DOCUMENT_TYPES = %w[application/pdf text/plain text/markdown text/csv].freeze

  belongs_to :account
  belongs_to :smart_assistant
  has_many :chunks, class_name: 'SmartAssistant::Chunk', foreign_key: :smart_assistant_source_id,
                    inverse_of: :source, dependent: :delete_all
  has_one_attached :file

  # text: free text, faq: a question (title) and its answer (content), website: one page, document: an upload
  enum kind: { text: 0, faq: 1, website: 2, document: 3 }
  enum status: { pending: 0, processing: 1, ready: 2, failed: 3 }

  validates :title, presence: true, length: { maximum: 255 }
  validates :content, length: { maximum: MAX_CONTENT_LENGTH }
  validates :content, presence: true, if: -> { text? || faq? }
  validates :url, presence: true, format: { with: %r{\Ahttps?://\S+\z}i }, if: :website?
  validate :document_file, if: :document?

  before_validation :set_account
  after_create_commit :ingest_later

  scope :latest, -> { order(created_at: :desc) }

  def ingest_later
    SmartAssistant::IngestSourceJob.perform_later(id)
  end

  private

  def set_account
    self.account_id = smart_assistant&.account_id
  end

  def document_file
    return errors.add(:file, :blank) unless file.attached?
    return errors.add(:file, :invalid) unless DOCUMENT_TYPES.include?(file.blob.content_type)

    errors.add(:file, :too_large) if file.blob.byte_size > MAX_FILE_SIZE
  end
end
