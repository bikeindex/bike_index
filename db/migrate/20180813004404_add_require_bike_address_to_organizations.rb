class AddRequireBikeAddressToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :require_address_on_registration, :boolean, default: false, null: false
  end
end
