class CreateOrganizationManufacturers < ActiveRecord::Migration[5.2]
  def change
    create_table :organization_manufacturers do |t|
      t.references :manufacturer, index: true
      t.references :organization, index: true

      t.boolean :can_view_counts, default: false

      t.timestamps
    end

    add_reference :organizations, :manufacturer, index: true
  end
end
