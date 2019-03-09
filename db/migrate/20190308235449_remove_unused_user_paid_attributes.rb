class RemoveUnusedUserPaidAttributes < ActiveRecord::Migration
  def change
    remove_column :users, :is_paid_member, :boolean
    remove_column :users, :paid_membership_info, :text
  end
end
