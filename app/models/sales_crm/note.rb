# Custom (MyDesk): a note (ملاحظة) written by an agent on a deal
class SalesCrm::Note < ApplicationRecord
  belongs_to :account
  belongs_to :deal, class_name: 'SalesCrm::Deal', inverse_of: :notes
  belongs_to :user, optional: true

  validates :content, presence: true, length: { maximum: 10_000 }
end
