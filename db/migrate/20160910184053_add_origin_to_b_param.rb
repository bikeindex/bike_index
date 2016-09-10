class AddOriginToBParam < ActiveRecord::Migration
  def change
    add_column :b_params, :origin, :string
  end
end
