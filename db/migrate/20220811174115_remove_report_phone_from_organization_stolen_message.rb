class RemoveReportPhoneFromOrganizationStolenMessage < ActiveRecord::Migration[6.1]
  def change
    remove_column :organization_stolen_messages, :report_phone, :string
  end
end
