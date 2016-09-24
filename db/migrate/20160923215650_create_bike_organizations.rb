class CreateBikeOrganizations < ActiveRecord::Migration
  def change
    create_table :bike_organizations do |t|
      t.references :bike, index: true
      t.references :organization, index: true

      t.timestamps null: false
    end
  end
end
