class CreateOrganizationEmailBlocks < ActiveRecord::Migration
  def change
    create_table :organization_email_blocks do |t|
      t.references :organization
      t.string :block_type
      t.text :body

      t.timestamps null: false
    end
  end
end
