class RemoveDeprecatedColumns < ActiveRecord::Migration[5.2]
  def change
    # Remove columns made unnecessary by PR#1875
    remove_column :external_registry_bikes, :old_status, :string
    remove_column :bike, :is_stolen, :boolean
    remove_column :bike, :is_abandoned, :boolean
    # Remove this column, it's unused and unnecessary
    remove_column :stolen_records, :time, :text

    # Parking Notifications are now tracked through creation_states
    remove_column :bikes, :created_by_parking_notification, :boolean

    # impound_configuration tracks public_impound_bikes
    remove_column :organizations, :public_impound_bikes, :boolean
  end
end
