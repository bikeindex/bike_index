class AddPartialIndexesToBikes < ActiveRecord::Migration[8.0]
  def change
    # Remove existing indexes and add partial indexes (only index when not null)
    # This optimizes index size and query performance for sparse columns

    remove_index :bikes, :address_record_id, if_exists: true
    add_index :bikes, :address_record_id, where: "address_record_id IS NOT NULL"

    remove_index :bikes, :current_impound_record_id, if_exists: true
    add_index :bikes, :current_impound_record_id, where: "current_impound_record_id IS NOT NULL"

    remove_index :bikes, :current_stolen_record_id, if_exists: true
    add_index :bikes, :current_stolen_record_id, where: "current_stolen_record_id IS NOT NULL"

    remove_index :bikes, :deleted_at, if_exists: true
    add_index :bikes, :deleted_at, where: "deleted_at IS NOT NULL"

    remove_index :bikes, :example, if_exists: true
    add_index :bikes, :example, where: "example IS NOT NULL"

    remove_index :bikes, :model_audit_id, if_exists: true
    add_index :bikes, :model_audit_id, where: "model_audit_id IS NOT NULL"

    remove_index :bikes, :creation_organization_id, name: "index_bikes_on_organization_id", if_exists: true
    add_index :bikes, :creation_organization_id, where: "creation_organization_id IS NOT NULL"

    remove_index :bikes, :paint_id, if_exists: true
    add_index :bikes, :paint_id, where: "paint_id IS NOT NULL"

    remove_index :bikes, :primary_activity_id, if_exists: true
    add_index :bikes, :primary_activity_id, where: "primary_activity_id IS NOT NULL"

    remove_index :bikes, :secondary_frame_color_id, if_exists: true
    add_index :bikes, :secondary_frame_color_id, where: "secondary_frame_color_id IS NOT NULL"

    remove_index :bikes, :tertiary_frame_color_id, if_exists: true
    add_index :bikes, :tertiary_frame_color_id, where: "tertiary_frame_color_id IS NOT NULL"

    remove_index :bikes, :user_hidden, if_exists: true
    add_index :bikes, :user_hidden, where: "user_hidden IS NOT NULL"
  end
end
