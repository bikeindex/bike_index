class CreateModelAudits < ActiveRecord::Migration[6.1]
  def change
    create_table :model_audits do |t|
      t.integer :propulsion_type
      t.references :manufacturer, index: true
      t.string :manufacturer_other
      t.string :frame_model

      t.integer :certification_status

      t.timestamps
    end
    add_reference :bikes, :model_audit, index: true
  end
end
