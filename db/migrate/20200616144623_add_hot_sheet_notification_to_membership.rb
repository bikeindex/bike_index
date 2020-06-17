class AddHotSheetNotificationToMembership < ActiveRecord::Migration[5.2]
  def change
    add_column :memberships, :hot_sheet_notification, :integer, default: 0
  end
end
