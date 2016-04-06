class AddBikeAttrsToBParams < ActiveRecord::Migration
  def change
    add_column :b_params, :bike_attrs, :json
  end
end
