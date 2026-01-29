class MakeTwitterCredentialsOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :social_accounts, :consumer_key, true
    change_column_null :social_accounts, :consumer_secret, true
    change_column_null :social_accounts, :user_secret, true
  end
end
