class RemoveHandlebarTypeOther < ActiveRecord::Migration[5.2]
  def change
    remove_column :bikes, :handlebar_type_other, :string
    remove_column :bikes, :propulsion_type_other, :string
  end
end
