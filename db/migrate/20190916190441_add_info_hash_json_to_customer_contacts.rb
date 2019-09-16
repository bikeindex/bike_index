class AddInfoHashJsonToCustomerContacts < ActiveRecord::Migration
  def change
    change_table :customer_contacts do |t|
      t.jsonb :info_hash_json, default: {}
    end
  end
end
