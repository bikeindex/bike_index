class RemoveOrganizationBooleansReplacedByPaidFeatureSlugs < ActiveRecord::Migration
  def change
    remove_column :organizations, :abandoned_bike_emails, :boolean
    remove_column :organizations, :geolocated_emails, :boolean
    remove_column :paid_features, :slug, :string
  end
end
