class CreateTwitterAccounts < ActiveRecord::Migration[4.2]
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
      t.string :consumer_key, null: false
      t.string :consumer_secret, null: false
      t.string :country
      t.string :language
      t.string :neighborhood
      t.string :screen_name, null: false, index: true
      t.string :state
      t.string :user_secret, null: false
      t.string :user_token, null: false
      t.jsonb :twitter_account_info, default: {}

      t.timestamps null: false
    end

    add_index :twitter_accounts,
      %i[latitude longitude],
      name: :index_twitter_accounts_on_latitude_and_longitude
  end
end
