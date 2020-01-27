class AddTheftAlertsNotes < ActiveRecord::Migration[4.2]
  def change
    add_column :theft_alerts, :notes, :text
  end
end
