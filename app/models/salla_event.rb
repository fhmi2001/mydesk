# == Schema Information
#
# Table name: salla_events
#
#  id              :bigint           not null, primary key
#  customer_mobile :string
#  customer_name   :string
#  event           :string           not null
#  order_reference :string
#  payload         :jsonb            not null
#  status_name     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  hook_id         :bigint
#  merchant_id     :string           not null
#  order_id        :string
#
# Indexes
#
#  index_salla_events_on_account_id_and_created_at  (account_id,created_at)
#  index_salla_events_on_account_id_and_event       (account_id,event)
#

# Custom (MyDesk): one webhook received from a connected Salla store
class SallaEvent < ApplicationRecord
  belongs_to :account
  belongs_to :hook, class_name: 'Integrations::Hook', optional: true

  validates :merchant_id, :event, presence: true

  scope :orders, -> { where('event LIKE ?', 'order.%') }
  scope :latest, -> { order(created_at: :desc) }
end
