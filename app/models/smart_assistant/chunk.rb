# Custom (MyDesk): an embedded passage of a knowledge source, searched by meaning when a customer asks
# == Schema Information
#
# Table name: smart_assistant_chunks
#
#  id                        :bigint           not null, primary key
#  content                   :text             not null
#  embedding                 :vector(1536)
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  smart_assistant_source_id :bigint           not null
#
# Indexes
#
#  index_smart_assistant_chunks_on_account_id                 (account_id)
#  index_smart_assistant_chunks_on_embedding                  (embedding) USING hnsw
#  index_smart_assistant_chunks_on_smart_assistant_source_id  (smart_assistant_source_id)
#
class SmartAssistant::Chunk < ApplicationRecord
  belongs_to :source, class_name: 'SmartAssistant::Source', foreign_key: :smart_assistant_source_id, inverse_of: :chunks

  has_neighbors :embedding, normalize: true

  scope :searchable_for, ->(account_id) { where(account_id: account_id).joins(:source).merge(SmartAssistant::Source.ready) }
end
