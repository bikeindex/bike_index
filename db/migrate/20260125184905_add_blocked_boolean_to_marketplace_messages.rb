class AddBlockedBooleanToMarketplaceMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :marketplace_messages, :blocked, :boolean, default: false, null: false
  end
end
