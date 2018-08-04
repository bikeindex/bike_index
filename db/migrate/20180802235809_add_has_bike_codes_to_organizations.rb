class AddHasBikeCodesToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :has_bike_codes, :boolean, default: false, null: false
  end
end
