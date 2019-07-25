class AddTheftAlertsNotes < ActiveRecord::Migration
  def change
    add_column :theft_alerts, :notes, :text
  end
end
