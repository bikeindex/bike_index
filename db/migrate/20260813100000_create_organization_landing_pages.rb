class CreateOrganizationLandingPages < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_landing_pages do |t|
      t.references :organization, null: false, index: {unique: true}
      t.text :body
      t.boolean :enabled, default: false, null: false

      t.timestamps
    end
  end
end
