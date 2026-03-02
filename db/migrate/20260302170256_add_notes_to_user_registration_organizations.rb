class AddNotesToUserRegistrationOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :user_registration_organizations, :notes, :text
  end
end
