class CreateModelTrackers < ActiveRecord::Migration[6.1]
  def change
    create_table :model_trackers do |t|
      t.integer :propulsion_type
      t.references :manufacturer, index: true
      t.string :manufacturer_other
      t.string :frame_model

      t.integer :certification_status

      t.timestamps
    end
    add_reference :bikes, :model_tracker, index: true
  end
end
