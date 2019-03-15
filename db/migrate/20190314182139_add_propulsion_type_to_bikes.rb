class AddPropulsionTypeToBikes < ActiveRecord::Migration
  def up
    add_column :bikes, :propulsion_type, :integer, default: 0
    
    Deprecated::PropulsionType.find_each do |pt|
      slug = pt.slug == "other" ? "other-style" : pt.slug
      Bike.where(propulsion_type_id: pt.id).update_all(propulsion_type: Bike.propulsion_types[slug])
    end
  end
  
  def down
    remove_column :bikes, :propulsion_type
  end
end