class AddDeliveryStatusEnumToHotSheets < ActiveRecord::Migration[8.1]
  def change
    rename_column :hot_sheets, :delivery_status, :delivery_status_legacy
    add_column :hot_sheets, :delivery_status, :integer, default: 0
    add_column :hot_sheets, :delivery_error, :string
    add_column :hot_sheets, :message_id, :string
    # email_success was the only value the string column ever held, and 1 is delivery_success.
    # Without this every existing sheet is delivery_pending, so the day's delivered sheets send again
    reversible do |dir|
      dir.up { execute "UPDATE hot_sheets SET delivery_status = 1 WHERE delivery_status_legacy = 'email_success'" }
    end
  end
end
