class CreateOrganizationFees < ActiveRecord::Migration
  def change
    create_table :organization_fees do |t|
      t.references :organization
      t.integer :kind, default: 0, null: 0
      t.string :name
      t.integer :upfront_cents
      t.integer :annual_cents

      t.timestamps null: false
    end
  end
end
