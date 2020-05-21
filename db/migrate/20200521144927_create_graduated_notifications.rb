class CreateGraduatedNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :graduated_notifications do |t|
      t.references :organization, index: true
      t.references :bike, index: true
      t.references :user, index: true
      t.references :primary_bike, index: true
      t.references :primary_notification, index: true

      t.text :marked_remaining_link_token
      t.datetime :marked_remaining_at

      t.integer :status, default: 0
      t.string :email
      t.string :delivery_status

      t.timestamps
    end
  end
end
