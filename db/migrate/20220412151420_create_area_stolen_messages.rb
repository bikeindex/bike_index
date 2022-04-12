class CreateAreaStolenMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :area_stolen_messages do |t|
      t.references :organization, index: true
      t.float :latitude
      t.float :longitude
      t.float :radius_miles
      t.text :message
      t.references :updator, index: true
      t.boolean :enabled, default: false

      t.timestamps
    end
    add_reference :stolen_records, :area_stolen_message
  end
end
