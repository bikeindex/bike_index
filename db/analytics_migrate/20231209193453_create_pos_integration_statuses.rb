class CreatePosIntegrationStatuses < ActiveRecord::Migration[6.1]
  def change
    create_table :pos_integration_statuses do |t|
      t.references :organization
      t.integer :pos_kind
      t.datetime :start_at
      t.datetime :end_at

      t.timestamps
    end
  end
end
