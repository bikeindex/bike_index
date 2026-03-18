class CreateBikeOrganizationNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :bike_organization_notes do |t|
      t.references :bike_organization, null: false, foreign_key: false, index: {unique: true}
      t.text :body
      t.references :user, null: false, foreign_key: false

      t.timestamps
    end
  end
end
