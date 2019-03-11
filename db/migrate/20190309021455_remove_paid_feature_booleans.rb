class RemovePaidFeatureBooleans < ActiveRecord::Migration
  def change
    remove_column :organizations, :has_bike_codes, :boolean
    remove_column :organizations, :show_partial_registrations, :boolean
    remove_column :organizations, :show_bulk_import, :boolean
  end
end
