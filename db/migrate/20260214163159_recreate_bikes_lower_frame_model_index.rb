class RecreateBikesLowerFrameModelIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    remove_index :bikes, name: "index_bikes_on_lower_frame_model", if_exists: true, algorithm: :concurrently
    add_index :bikes, "LEFT(LOWER(frame_model), 255)", name: "index_bikes_on_lower_frame_model", algorithm: :concurrently
  end
end
