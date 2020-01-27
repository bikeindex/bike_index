class AddLatLongToBikes < ActiveRecord::Migration[4.2]
  def change
    change_table :bikes do |t|
      t.string :city
      t.float :latitude
      t.float :longitude
    end

    add_index :bikes, [:latitude, :longitude]
  end
end
