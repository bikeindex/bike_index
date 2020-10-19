class RemoveRegisteredNewFromBikesAndAddPreviousOwnership < ActiveRecord::Migration[5.2]
  def change
    remove_column :bikes, :registered_new, :boolean
    add_reference :ownerships, :previous_ownership, index: false
  end
end
