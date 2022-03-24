class AddLocationStolenMessagingAttributes < ActiveRecord::Migration[6.1]
  def change
    # Default to match the default of organization#search_radius
    add_column :organizations, :location_stolen_message_radius_miles, :float, default: 50.0
    add_column :stolen_records, :location_stolen_message_id, :integer
    remove_column :mail_snippets, :is_location_triggered, :boolean
  end
end
