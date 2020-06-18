class CreateAppointmentConfigurations < ActiveRecord::Migration[5.2]
  def change
    create_table :appointment_configurations do |t|
      t.references :organization
      t.references :location
      t.jsonb :reasons
      t.boolean :virtual_line_enabled, default: false

      t.timestamps
    end
  end
end
