# Custom (MyDesk): one stage (مرحلة) of a pipeline, with the probability used for the expected value and a kind
# that decides a deal's status. The database allows exactly one won and one lost stage per pipeline.
class SalesCrm::Stage < ApplicationRecord
  DEFAULT_COLORS = { 'open' => '#94a3b8', 'won' => '#22c55e', 'lost' => '#ef4444' }.freeze

  belongs_to :account
  belongs_to :pipeline, class_name: 'SalesCrm::Pipeline', inverse_of: :stages
  has_many :deals, class_name: 'SalesCrm::Deal', dependent: :restrict_with_error, inverse_of: :stage

  enum kind: { open: 0, won: 1, lost: 2 }

  validates :name, presence: true, length: { maximum: 60 }
  validates :probability, numericality: { only_integer: true, in: 0..100 }
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }

  before_validation :default_color
  before_validation { self.account_id ||= pipeline&.account_id }

  private

  def default_color
    self.color = DEFAULT_COLORS[kind] if color.blank?
  end
end
