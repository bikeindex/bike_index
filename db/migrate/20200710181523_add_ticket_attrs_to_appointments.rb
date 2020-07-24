class AddTicketAttrsToAppointments < ActiveRecord::Migration[5.2]
  def change
    add_column :appointments, :appointment_at, :datetime
    add_column :appointments, :ticket_number, :integer
    add_column :appointments, :creation_ip_address, :inet
    rename_column :appointments, :line_entry_timestamp, :position_in_line
  end
end
