class AddRequireBikeAddressToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :require_address_on_registration, :boolean, default: false, null: false
  end
end
