class AddKindToCustomerContacts < ActiveRecord::Migration[4.2]
  def change
    add_column :customer_contacts, :kind, :integer, default: 0, null: false
  end
end
