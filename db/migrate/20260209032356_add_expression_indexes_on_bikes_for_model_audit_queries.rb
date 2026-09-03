class AddExpressionIndexesOnBikesForModelAuditQueries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :bikes, "LOWER(mnfg_name)", name: "index_bikes_on_lower_mnfg_name", algorithm: :concurrently, if_not_exists: true
    add_index :bikes, "LEFT(LOWER(frame_model), 255)", name: "index_bikes_on_lower_frame_model", algorithm: :concurrently, if_not_exists: true
  end
end
