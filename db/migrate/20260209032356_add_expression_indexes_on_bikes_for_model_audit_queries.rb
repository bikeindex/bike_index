class AddExpressionIndexesOnBikesForModelAuditQueries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :bikes, "LOWER(mnfg_name)", name: "index_bikes_on_lower_mnfg_name", algorithm: :concurrently
    add_index :bikes, "LOWER(frame_model)", name: "index_bikes_on_lower_frame_model", algorithm: :concurrently
  end
end
