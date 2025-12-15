class AddDoorkeeperAppIdToOwnerships < ActiveRecord::Migration[8.0]
  def change
    add_reference :ownerships, :doorkeeper_app, index: true
  end
end
