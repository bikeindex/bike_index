class CreateRecoveryDisplays < ActiveRecord::Migration
  def change
    create_table :recovery_displays do |t|
      t.integer :stolenRecord_id
      t.text :quote
      t.string :quote_by
      t.datetime :date_recovered
      t.string :link
      t.string :image

      t.timestamps
    end
    add_index :recovery_displays, :stolenRecord_id
  end
end
