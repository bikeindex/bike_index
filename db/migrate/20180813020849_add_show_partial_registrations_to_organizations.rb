class AddShowPartialRegistrationsToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :show_partial_registrations, :boolean, default: false, null: false
  end
end
