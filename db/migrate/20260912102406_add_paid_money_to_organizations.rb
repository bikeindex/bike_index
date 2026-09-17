class AddPaidMoneyToOrganizations < ActiveRecord::Migration[8.1]
  # Existing organizations are set by Backfills::OrganizationPaidMoneyJob
  def change
    add_column :organizations, :paid_money, :boolean, default: false, null: false
  end
end
