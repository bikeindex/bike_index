class DropFlavorTextsTable < ActiveRecord::Migration[4.2]
  def change
    drop_table :flavor_texts
  end
end
