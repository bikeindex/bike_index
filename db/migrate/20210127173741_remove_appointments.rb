class RemoveAppointments < ActiveRecord::Migration[5.2]
  def change
    drop_table :appointments
    drop_table :appointment_configurations
    drop_table :appointment_updates
  end
end
