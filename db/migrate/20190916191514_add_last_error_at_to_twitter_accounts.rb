class AddLastErrorAtToTwitterAccounts < ActiveRecord::Migration[4.2]
  def change
    add_column :twitter_accounts, :last_error_at, :datetime
  end
end
