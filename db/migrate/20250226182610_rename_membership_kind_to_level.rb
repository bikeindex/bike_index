class RenameMembershipKindToLevel < ActiveRecord::Migration[8.0]
  def change
    rename_column :memberships, :kind, :level
    rename_column :stripe_prices, :membership_kind, :membership_level
  end
end
