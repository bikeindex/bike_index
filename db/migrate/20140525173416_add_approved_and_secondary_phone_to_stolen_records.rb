class AddApprovedAndSecondaryPhoneToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :secondary_phone, :string
    add_column :stolen_records, :approved, :boolean, default: false, null: false
  end
end
