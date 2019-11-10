class AddLocationFieldsToOrganization < ActiveRecord::Migration
  def change
    change_table :organizations do |t|
      # geocoding for regional organization associations
      t.string :city
      t.string :zipcode
      t.belongs_to :state, index: true, foreign_key: true
      t.belongs_to :country, index: true, foreign_key: true
      t.integer :search_radius, null: false, default: 50
      t.float :latitude
      t.float :longitude

      # geocoding for regional organization associations
      t.integer :regional_organization_id, index: true
      t.boolean :regional, null: false, default: false
    end

    add_index :organizations, [:latitude, :longitude]
  end
end
