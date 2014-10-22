class AddInfoHashToCustomerContacts < ActiveRecord::Migration
  def change
    add_column :customer_contacts, :info_hash, :text
  end
end
