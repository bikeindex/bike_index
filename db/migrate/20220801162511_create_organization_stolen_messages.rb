class CreateOrganizationStolenMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :organization_stolen_messages do |t|
      t.references :organization, index: true
      t.integer :kind
      t.float :latitude
      t.float :longitude
      t.float :search_radius_miles
      t.text :body
      t.references :updator, index: true
      t.boolean :is_enabled, default: false
      t.datetime :content_added_at

      t.timestamps
    end
    add_reference :stolen_records, :organization_stolen_message
  end
end
