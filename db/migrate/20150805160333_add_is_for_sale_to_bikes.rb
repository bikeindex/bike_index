class AddIsForSaleToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :is_for_sale, :boolean, default: false, null: false
  end
end
