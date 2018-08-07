class AddAdditionalPaidAttributesToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :geolocated_emails, :boolean, default: false, null: false
    add_column :organizations, :abandoned_bike_emails, :boolean, default: false, null: false
  end
end
