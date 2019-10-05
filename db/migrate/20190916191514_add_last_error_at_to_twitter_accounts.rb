class AddLastErrorAtToTwitterAccounts < ActiveRecord::Migration
  def change
    add_column :twitter_accounts, :last_error_at, :datetime
  end
end
