class RenameInfoHashToInfoHashTextOnCustomerContacts < ActiveRecord::Migration
  def change
    rename_column :customer_contacts, :info_hash, :info_hash_text
    add_column :customer_contacts, :info_hash, :jsonb, default: {}
  end
end
