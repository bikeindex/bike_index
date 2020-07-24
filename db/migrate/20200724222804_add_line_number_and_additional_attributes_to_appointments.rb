class AddLineNumberAndAdditionalAttributesToAppointments < ActiveRecord::Migration[5.2]
  def change
    add_column :appointments, :appointment_at, :datetime
    add_column :appointments, :creation_ip_address, :inet
    add_reference :notifications, :appointment, index: true

    # TODO: rename rather than just adding, once everything is working
    # rename_column :appointments, :line_entry_timestamp, :line_number
    add_column :appointments, :line_number, :integer
  end
end
