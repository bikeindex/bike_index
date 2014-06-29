class AddBikesCountToPaints < ActiveRecord::Migration
  def change
    add_column :paints, :bikes_count, :integer, default: 0, null: false
  end
end
