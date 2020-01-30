class DropInfoHashTextFromCustomerContacts < ActiveRecord::Migration[4.2]
  def change
    remove_column :customer_contacts, :info_hash_text, :text
  end
end
