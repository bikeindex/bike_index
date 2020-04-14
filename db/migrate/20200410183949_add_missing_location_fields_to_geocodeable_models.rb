class AddMissingLocationFieldsToGeocodeableModels < ActiveRecord::Migration[5.2]
  # Ensure all geo models have the following fields:
  # - street
  # - city
  # - zipcode
  # - state_id
  # - country_id
  def change
    change_table :mail_snippets do |t|
      t.column :street, :string
      t.column :city, :string
      t.column :zipcode, :string
      t.belongs_to :state, index: true
      t.belongs_to :country, index: true
    end

    change_table :bikes do |t|
      t.column :street, :string
      t.belongs_to :state, index: true
    end

    change_table :twitter_accounts do |t|
      t.column :street, :string
      t.column :zipcode, :string
      # data-migrate current state and country to foreign keys
      t.belongs_to :state, index: true
      t.belongs_to :country, index: true
    end
  end
end
