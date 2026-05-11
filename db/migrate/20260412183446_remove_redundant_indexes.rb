class RemoveRedundantIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :bike_organization_notes, :bike_id, name: :index_bike_organization_notes_on_bike_id
    remove_index :strava_activities, :strava_integration_id, name: :index_strava_activities_on_strava_integration_id
    remove_index :strava_gears, :strava_integration_id, name: :index_strava_gears_on_strava_integration_id
    add_index :user_emails, :email, where: "confirmation_token IS NULL", name: :index_user_emails_on_email_confirmed, algorithm: :concurrently
  end
end
