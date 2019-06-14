class DropFlavorTextsTable < ActiveRecord::Migration
  def change
    drop_table :flavor_texts
  end
end
