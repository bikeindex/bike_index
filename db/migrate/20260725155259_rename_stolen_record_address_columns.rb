class RenameStolenRecordAddressColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :stolen_records, :zipcode, :postal_code
    rename_column :stolen_records, :state_id, :region_record_id
    add_column :stolen_records, :region_string, :string
  end
end
