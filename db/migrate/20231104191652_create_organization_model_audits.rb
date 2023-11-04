class CreateOrganizationModelAudits < ActiveRecord::Migration[6.1]
  def change
    create_table :organization_model_audits do |t|
      t.references :model_audit
      t.references :organization

      t.integer :certification_status

      t.integer :bikes_count, default: 0

      t.timestamps
    end
  end
end
