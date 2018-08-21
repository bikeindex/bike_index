class AddOrganizationAttributesForPayments < ActiveRecord::Migration
  def change
    add_column :payments, :kind, :integer, default: 0
    add_reference :payments, :organization
    add_reference :payments, :invoice
    add_column :organizations, :paid_feature_slugs, text: true, array: true, default: []
  end
end
