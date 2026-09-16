class AddDeliveryStatusEnumToHotSheets < ActiveRecord::Migration[8.1]
  def change
    rename_column :hot_sheets, :delivery_status, :delivery_status_legacy
    add_column :hot_sheets, :delivery_status, :integer, default: 0
    add_column :hot_sheets, :delivery_error, :string
    add_column :hot_sheets, :message_id, :string
    # email_success was the string column's only value, and 1 is delivery_success. Without this
    # the day's sent sheets read as unsent, and the next run mails them again
    reversible do |dir|
      dir.up { execute "UPDATE hot_sheets SET delivery_status = 1 WHERE delivery_status_legacy = 'email_success'" }
    end

    remove_column :organization_roles, :receive_hot_sheet, :boolean, default: false
  end
end
