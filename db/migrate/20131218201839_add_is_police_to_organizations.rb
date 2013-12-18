class AddIsPoliceToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :is_police, :boolean
  end
end
