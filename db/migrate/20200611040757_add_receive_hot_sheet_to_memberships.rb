class AddReceiveHotSheetToMemberships < ActiveRecord::Migration[5.2]
  def change
    add_column :memberships, :receive_hot_sheet, :boolean, default: false
  end
end
