class AddSizeToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :frame_size, :string
    add_column :bikes, :frame_size_unit, :string
  end
end
