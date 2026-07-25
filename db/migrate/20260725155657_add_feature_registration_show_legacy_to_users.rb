class AddFeatureRegistrationShowLegacyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :feature_registration_show_legacy, :boolean, default: false, null: false
  end
end
