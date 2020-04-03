class RenameAdditionalRegistrationToExtraRegistrationNumber < ActiveRecord::Migration[5.2]
  def change
    rename_column :bikes, :additional_registration, :extra_registration_number
    rename_column :external_registry_bikes, :additional_registration, :extra_registration_number
  end
end
