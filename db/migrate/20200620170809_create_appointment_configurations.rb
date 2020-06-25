class CreateAppointmentConfigurations < ActiveRecord::Migration[5.2]
  def change
    create_table :appointment_configurations do |t|
      t.references :organization
      t.references :location
      t.jsonb :reasons
      t.boolean :virtual_line_on, default: false
      t.integer :customers_on_deck_count

      t.timestamps
    end
  end
end
