class AddRegistrationFieldLabelsToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :registration_field_labels, :jsonb, default: {}
  end
end
