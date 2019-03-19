class AddRegistrationFieldLabelsToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :registration_field_labels, :jsonb, default: {}
  end
end
