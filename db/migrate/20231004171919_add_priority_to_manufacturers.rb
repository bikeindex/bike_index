class AddPriorityToManufacturers < ActiveRecord::Migration[6.1]
  def change
    add_column :manufacturers, :priority, :integer
  end
end
