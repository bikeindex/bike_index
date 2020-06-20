class CreateAppointments < ActiveRecord::Migration[5.2]
  def change
    create_table :appointments do |t|
      t.references :location
      t.references :organization
      t.references :user
      t.references :bike

      t.string :email
      t.text :link_token

      t.integer :status

      t.string :reason
      t.text :description

      t.datetime :appointment_time

      t.timestamps
    end
  end
end
