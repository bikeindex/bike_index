class CreatePrimaryActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :primary_activities do |t|
      t.string :name
      t.string :slug
      t.references :primary_activity_family
      t.boolean :family
      t.integer :priority

      t.timestamps
    end
    add_reference :bikes, :primary_activity
    add_reference :bike_versions, :primary_activity
  end
end
