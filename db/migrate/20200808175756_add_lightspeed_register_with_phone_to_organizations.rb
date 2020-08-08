class AddLightspeedRegisterWithPhoneToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :lightspeed_register_with_phone, :boolean, default: false
  end
end
