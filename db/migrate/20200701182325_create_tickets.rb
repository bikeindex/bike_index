class CreateTickets < ActiveRecord::Migration[5.2]
  def change
    create_table :tickets do |t|
      t.references :organization
      t.references :location
      t.references :appointment
      t.integer :number
      t.integer :status, default: 0
      t.text :link_token

      t.timestamps
    end
  end
end
