class CreateCreationStates < ActiveRecord::Migration
  def change
    create_table :creation_states do |t|
      t.references :bike, index: true
      t.references :organization, index: true
      t.string :origin
      t.boolean :is_bulk

      t.timestamps null: false
    end
  end
end
