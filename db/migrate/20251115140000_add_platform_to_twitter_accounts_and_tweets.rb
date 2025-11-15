class AddPlatformToTwitterAccountsAndTweets < ActiveRecord::Migration[8.0]
  def change
    add_column :twitter_accounts, :platform, :integer, default: 0, null: false
    add_column :tweets, :platform, :integer, default: 0, null: false

    add_index :twitter_accounts, :platform
    add_index :tweets, :platform
  end
end
