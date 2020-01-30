class RemoveContactTypeFromCustomerContacts < ActiveRecord::Migration[4.2]
  def change
    remove_column :customer_contacts, :contact_type, :string
  end
end
