class CreatePropertyClaims < ActiveRecord::Migration[5.2]
  def change
    create_table :property_claims do |t|
      t.references :impound_record, index: true
      t.references :stolen_record, index: true
      t.references :user, index: true

      t.text :message
      t.json :data

      t.integer :status
      t.datetime :submitted_at

      t.timestamps
    end
  end
end
