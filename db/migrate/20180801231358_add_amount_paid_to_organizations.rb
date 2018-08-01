class AddAmountPaidToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :upfront_payment_cents, :integer
    add_column :organizations, :annual_payment_cents, :integer
  end
end
