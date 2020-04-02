class CreateLocationSchedules < ActiveRecord::Migration[5.2]
  def change
    add_column :locations, :timezone, :string # Sneaking it in there like a sneaky snake
    create_table :location_schedules do |t|
      t.references :location
      t.integer :day
      t.integer :day_int
      t.date :date
      t.jsonb :schedule, default: {}
      t.boolean :set_closed, default: false, null: false

      t.timestamps
    end
  end
end
