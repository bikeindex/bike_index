class AddReplyTokenToMarketplaceMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :marketplace_messages, :reply_token, :string
    add_index :marketplace_messages, :reply_token, unique: true
  end
end
