class AddCanSendManyMarketplaceMessagesToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :can_send_many_marketplace_messages, :boolean, default: false, null: false
  end
end
