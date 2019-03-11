class RemoveUnusedUserPaidAttributes < ActiveRecord::Migration
  def change
    remove_column :users, :is_paid_member, :boolean
    remove_column :users, :paid_membership_info, :text
    # Also, make this other serialized column json because that's better
    remove_column :users, :my_bikes_hash, :text
    add_column :users, :my_bikes_hash, :json
  end
end
