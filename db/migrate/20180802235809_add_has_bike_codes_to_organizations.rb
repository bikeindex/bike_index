class AddHasBikeCodesToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :has_bike_codes, :boolean, default: false, null: false
  end
end
