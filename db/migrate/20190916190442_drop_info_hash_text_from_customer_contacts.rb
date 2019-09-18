class DropInfoHashTextFromCustomerContacts < ActiveRecord::Migration
  def change
    remove_column :customer_contacts, :info_hash_text, :text
  end
end
