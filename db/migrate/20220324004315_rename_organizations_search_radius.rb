class RenameOrganizationsSearchRadius < ActiveRecord::Migration[6.1]
  def change
    rename_column :organizations, :search_radius, :search_radius_miles
    reversible do |mig|
      mig.up do
        change_column :organizations, :search_radius_miles, :float
      end
      mig.down do
        change_column :organizations, :search_radius_miles, :integer
      end
    end
  end
end
