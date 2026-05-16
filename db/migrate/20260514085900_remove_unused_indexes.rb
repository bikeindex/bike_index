class RemoveUnusedIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :users, :auth_token, name: :index_users_on_auth_token, algorithm: :concurrently
    remove_index :bikes, :address_record_id, name: :index_bikes_on_address_record_id, where: "address_record_id IS NOT NULL", algorithm: :concurrently
    remove_index :bike_organizations, :deleted_at, name: :index_bike_organizations_on_deleted_at, algorithm: :concurrently
    remove_index :ownerships, :impound_record_id, name: :index_ownerships_on_impound_record_id, algorithm: :concurrently
    remove_index :address_records, :region_record_id, name: :index_address_records_on_region_record_id, algorithm: :concurrently
    remove_index :bike_stickers, :secondary_organization_id, name: :index_bike_stickers_on_secondary_organization_id, algorithm: :concurrently
    remove_index :bikes, :paint_id, name: :index_bikes_on_paint_id, where: "paint_id IS NOT NULL", algorithm: :concurrently
    remove_index :stolen_records, :organization_stolen_message_id, name: :index_stolen_records_on_organization_stolen_message_id, algorithm: :concurrently
    remove_index :stolen_records, :recovering_user_id, name: :index_stolen_records_on_recovering_user_id, algorithm: :concurrently
    remove_index :user_alerts, :organization_id, name: :index_user_alerts_on_organization_id, algorithm: :concurrently
    remove_index :graduated_notifications, :bike_organization_id, name: :index_graduated_notifications_on_bike_organization_id, algorithm: :concurrently
    remove_index :bikes, :current_impound_record_id, name: :index_bikes_on_current_impound_record_id, algorithm: :concurrently
    remove_index :email_domains, :creator_id, name: :index_email_domains_on_creator_id, algorithm: :concurrently
    remove_index :stolen_notifications, :doorkeeper_app_id, name: :index_stolen_notifications_on_doorkeeper_app_id, algorithm: :concurrently
    remove_index :graduated_notifications, :marked_remaining_by_id, name: :index_graduated_notifications_on_marked_remaining_by_id, algorithm: :concurrently
    remove_index :parking_notifications, :region_record_id, name: :index_parking_notifications_on_region_record_id, algorithm: :concurrently
    remove_index :parking_notifications, :country_id, name: :index_parking_notifications_on_country_id, algorithm: :concurrently
    remove_index :parking_notifications, :retrieved_by_id, name: :index_parking_notifications_on_retrieved_by_id, algorithm: :concurrently
    remove_index :impound_record_updates, :user_id, name: :index_impound_record_updates_on_user_id, algorithm: :concurrently
    remove_index :stripe_subscriptions, :stripe_price_stripe_id, name: :index_stripe_subscriptions_on_stripe_price_stripe_id, algorithm: :concurrently
    remove_index :impound_record_updates, :location_id, name: :index_impound_record_updates_on_location_id, algorithm: :concurrently
    remove_index :exports, :user_id, name: :index_exports_on_user_id, algorithm: :concurrently
    remove_index :ambassador_task_assignments, :ambassador_task_id, name: :index_ambassador_task_assignments_on_ambassador_task_id, algorithm: :concurrently
    remove_index :bike_organization_notes, :organization_id, name: :index_bike_organization_notes_on_organization_id, algorithm: :concurrently
    remove_index :bike_organization_notes, :user_id, name: :index_bike_organization_notes_on_user_id, algorithm: :concurrently
    remove_index :bike_sticker_batches, :organization_id, name: :index_bike_sticker_batches_on_organization_id, algorithm: :concurrently
    remove_index :bike_sticker_batches, :user_id, name: :index_bike_sticker_batches_on_user_id, algorithm: :concurrently
    remove_index :bike_versions, :front_gear_type_id, name: :index_bike_versions_on_front_gear_type_id, algorithm: :concurrently
    remove_index :bike_versions, :front_wheel_size_id, name: :index_bike_versions_on_front_wheel_size_id, algorithm: :concurrently
    remove_index :bike_versions, :paint_id, name: :index_bike_versions_on_paint_id, algorithm: :concurrently
    remove_index :bike_versions, :primary_frame_color_id, name: :index_bike_versions_on_primary_frame_color_id, algorithm: :concurrently
    remove_index :bike_versions, :rear_gear_type_id, name: :index_bike_versions_on_rear_gear_type_id, algorithm: :concurrently
    remove_index :bike_versions, :rear_wheel_size_id, name: :index_bike_versions_on_rear_wheel_size_id, algorithm: :concurrently
    remove_index :bike_versions, :secondary_frame_color_id, name: :index_bike_versions_on_secondary_frame_color_id, algorithm: :concurrently
    remove_index :bike_versions, :tertiary_frame_color_id, name: :index_bike_versions_on_tertiary_frame_color_id, algorithm: :concurrently
    remove_index :external_registry_credentials, :type, name: :index_external_registry_credentials_on_type, algorithm: :concurrently
    remove_index :impound_configurations, :organization_id, name: :index_impound_configurations_on_organization_id, algorithm: :concurrently
    remove_index :mail_snippets, :doorkeeper_app_id, name: :index_mail_snippets_on_doorkeeper_app_id, algorithm: :concurrently
    remove_index :mail_snippets, :organization_id, name: :index_mail_snippets_on_organization_id, algorithm: :concurrently
    remove_index :marketplace_listings, :sale_id, name: :index_marketplace_listings_on_sale_id, algorithm: :concurrently
    remove_index :memberships, :creator_id, name: :index_memberships_on_creator_id, algorithm: :concurrently
    remove_index :model_attestations, :model_audit_id, name: :index_model_attestations_on_model_audit_id, algorithm: :concurrently
    remove_index :model_attestations, :user_id, name: :index_model_attestations_on_user_id, algorithm: :concurrently
    remove_index :organization_manufacturers, :manufacturer_id, name: :index_organization_manufacturers_on_manufacturer_id, algorithm: :concurrently
    remove_index :organization_stolen_messages, :updator_id, name: :index_organization_stolen_messages_on_updator_id, algorithm: :concurrently
    remove_index :sales, [:item_type, :item_id], name: :index_sales_on_item, algorithm: :concurrently
    remove_index :sales, :marketplace_message_id, name: :index_sales_on_marketplace_message_id, algorithm: :concurrently
    remove_index :sales, :ownership_id, name: :index_sales_on_ownership_id, algorithm: :concurrently
    remove_index :sales, :seller_id, name: :index_sales_on_seller_id, algorithm: :concurrently
    remove_index :social_accounts, :country_id, name: :index_social_accounts_on_country_id, algorithm: :concurrently
    remove_index :social_accounts, [:latitude, :longitude], name: :index_social_accounts_on_latitude_and_longitude, algorithm: :concurrently
    remove_index :social_accounts, :state_id, name: :index_social_accounts_on_state_id, algorithm: :concurrently
    remove_index :states, :country_id, name: :index_states_on_country_id, algorithm: :concurrently
    remove_index :stolen_bike_listings, :bike_id, name: :index_stolen_bike_listings_on_bike_id, algorithm: :concurrently
    remove_index :stolen_bike_listings, :initial_listing_id, name: :index_stolen_bike_listings_on_initial_listing_id, algorithm: :concurrently
    remove_index :stolen_bike_listings, :manufacturer_id, name: :index_stolen_bike_listings_on_manufacturer_id, algorithm: :concurrently
    remove_index :stolen_bike_listings, :primary_frame_color_id, name: :index_stolen_bike_listings_on_primary_frame_color_id, algorithm: :concurrently
    remove_index :stolen_bike_listings, :secondary_frame_color_id, name: :index_stolen_bike_listings_on_secondary_frame_color_id, algorithm: :concurrently
    remove_index :stolen_bike_listings, :tertiary_frame_color_id, name: :index_stolen_bike_listings_on_tertiary_frame_color_id, algorithm: :concurrently
    remove_index :strava_integrations, :deleted_at, name: :index_strava_integrations_on_deleted_at, algorithm: :concurrently
    remove_index :user_bans, :creator_id, name: :index_user_bans_on_creator_id, algorithm: :concurrently
  end
end
