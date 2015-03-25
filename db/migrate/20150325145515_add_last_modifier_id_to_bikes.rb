class AddLastModifierIdToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :updator_id, :integer
  end
end
