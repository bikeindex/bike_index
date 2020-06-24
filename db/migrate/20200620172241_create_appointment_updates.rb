class CreateAppointmentUpdates < ActiveRecord::Migration[5.2]
  def change
    create_table :appointment_updates do |t|
      t.references :appointment
      t.references :user
      t.integer :creator_type
      t.integer :status

      t.timestamps
    end
  end
end
