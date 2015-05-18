class AddIsStockToComponents < ActiveRecord::Migration
  def change
    add_column :components, :is_stock, :boolean, default: false, null: false
  end
end
