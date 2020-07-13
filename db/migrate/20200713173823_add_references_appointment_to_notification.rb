class AddReferencesAppointmentToNotification < ActiveRecord::Migration[5.2]
  def change
    add_reference :notifications, :appointments, index: true
  end
end
