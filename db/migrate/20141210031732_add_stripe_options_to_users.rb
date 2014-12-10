class AddStripeOptionsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :stripe_id, :string
    add_column :users, :is_paid_member, :boolean, default: false, null: false
    add_column :users, :paid_membership_info, :text
  end
end
