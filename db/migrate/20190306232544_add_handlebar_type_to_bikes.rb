class AddHandlebarTypeToBikes < ActiveRecord::Migration
  def up
    add_column :bikes, :handlebar_type, :integer

    defined?(Deprecated::HandlebarType) && Deprecated::HandlebarType.find_each do |ht|
      Bike.where(handlebar_type_id: ht.id).update_all(handlebar_type: Bike.handlebar_types[ht.slug])
    end
  end

  def down
    remove_column :bikes, :handlebar_type
  end
end
