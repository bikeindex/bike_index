class AddFrameSizeNumberToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :frame_size_number, :float
  end
end
