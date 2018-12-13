class RemoveUnusedOrganizationFieldsUseAdditionalRegistrationFieldAndRequireAddressOnRegistration < ActiveRecord::Migration
  def change
    remove_column :organizations, :use_additional_registration_field, :boolean
    remove_column :organizations, :require_address_on_registration, :boolean
  end
end
