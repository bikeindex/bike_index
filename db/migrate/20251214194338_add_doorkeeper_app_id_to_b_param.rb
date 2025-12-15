class AddDoorkeeperAppIdToBParam < ActiveRecord::Migration[8.0]
  def change
    add_reference :b_params, :doorkeeper_app, index: false
  end
end
