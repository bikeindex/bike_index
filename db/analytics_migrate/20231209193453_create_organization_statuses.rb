class CreateOrganizationStatuses < ActiveRecord::Migration[6.1]
  def change
    create_table :organization_statuses do |t|
      t.references :organization
      t.integer :pos_kind
      t.integer :kind
      t.datetime :organization_deleted_at

      t.datetime :start_at
      t.datetime :end_at

      t.timestamps
    end
  end
end
