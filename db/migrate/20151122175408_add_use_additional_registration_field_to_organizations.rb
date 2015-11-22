class AddUseAdditionalRegistrationFieldToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :use_additional_registration_field, :boolean, default: false, null: false
  end
end
