class AddReferencesAppointmentToNotification < ActiveRecord::Migration[5.2]
  def change
    add_reference :notifications, :appointment, index: true
  end
end
