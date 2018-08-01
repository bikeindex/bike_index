class AddAdditionalPaidAttributesToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :paid_at, :datetime
    add_column :organizations, :geolocated_emails, :boolean, default: false, null: false
  end
end
