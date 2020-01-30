class AddShowPartialRegistrationsToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :show_partial_registrations, :boolean, default: false, null: false
  end
end
