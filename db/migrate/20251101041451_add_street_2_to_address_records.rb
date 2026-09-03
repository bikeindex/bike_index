class AddStreet2ToAddressRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :address_records, :street_2, :string
  end
end
