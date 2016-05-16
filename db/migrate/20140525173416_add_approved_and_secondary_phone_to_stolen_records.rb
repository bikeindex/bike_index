class AddApprovedAndSecondaryPhoneToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :secondary_phone, :string
    add_column :stolenRecords, :approved, :boolean, default: false, null: false
  end
end
