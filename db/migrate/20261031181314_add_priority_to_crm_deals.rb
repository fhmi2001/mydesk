# Custom (MyDesk): a deal's priority (low / medium / high). Existing and new deals start at medium.
class AddPriorityToCrmDeals < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_deals, :priority, :integer, null: false, default: 1
  end
end
