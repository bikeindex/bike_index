class AddCycleTypeToBikes < ActiveRecord::Migration

  def up
    add_column :bikes, :cycle_type, :integer, default: 0
    
    Deprecated::CycleType.find_each do |ct|
      Bike.where(cycle_type_id: ct.id).update_all(cycle_type: Bike.cycle_types[ct.slug])
    end
  end

  def down
    remove_column :bikes, :cycle_type
  end
end
