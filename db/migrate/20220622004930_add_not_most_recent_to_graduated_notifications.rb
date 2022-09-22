class AddNotMostRecentToGraduatedNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :graduated_notifications, :not_most_recent, :boolean, default: false
  end
end
