class AddStolenLatAndLongToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :stolen_lat, :float
    add_column :bikes, :stolen_long, :float
    add_index :bikes, [:stolen_lat, :stolen_long]
  end
end
