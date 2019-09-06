class CreateTwitterAccounts < ActiveRecord::Migration
  def change
    create_table :twitter_accounts do |t|
      t.boolean :active, default: false, null: false
      t.boolean :default, default: false, null: false
      t.boolean :national, default: false, null: false
      t.float :latitude
      t.float :longitude
      t.string :address
      t.string :append_block
      t.string :city
      t.string :consumer_key
      t.string :consumer_secret
      t.string :country
      t.string :language
      t.string :neighborhood
      t.string :screen_name
      t.string :state
      t.string :user_secret
      t.string :user_token
      t.text :twitter_account_info

      t.timestamps null: false
    end

    add_index :twitter_accounts,
              %i[latitude longitude],
              name: :index_twitter_accounts_on_latitude_and_longitude
  end
end
