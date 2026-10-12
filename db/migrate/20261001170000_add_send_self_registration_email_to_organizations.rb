class AddSendSelfRegistrationEmailToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :send_self_registration_email, :boolean, default: false, null: false
  end
end
