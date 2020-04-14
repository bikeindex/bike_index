class DropStateAndCountryFromTwitterAccounts < ActiveRecord::Migration[5.2]
  def change
    remove_column :twitter_accounts, :state, :string
    remove_column :twitter_accounts, :country, :string
  end
end
