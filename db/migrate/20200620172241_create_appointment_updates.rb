class CreateAppointmentUpdates < ActiveRecord::Migration[5.2]
  def change
    create_table :appointment_updates do |t|
      t.references :appointment
      t.references :user
      t.integer :status
      t.boolean :organization_update, default: false

      t.timestamps
    end
  end
end
