class RemoveContactTypeFromCustomerContacts < ActiveRecord::Migration
  def change
    remove_column :customer_contacts, :contact_type, :string
  end
end
