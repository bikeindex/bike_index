class CreateUsStates < ActiveRecord::Migration
  def change
    create_table :us_states do |t|
      t.string :name
      t.string :abbreviation

      t.timestamps
    end
  end
end
