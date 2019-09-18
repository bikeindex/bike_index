class AddKindToCustomerContacts < ActiveRecord::Migration
  def change
    add_column :customer_contacts, :kind, :integer, default: 0, null: false
  end
end
