class AddIndexesForSlowQueries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :b_params, :email,
      using: :gin, opclass: :gin_trgm_ops,
      where: "created_bike_id IS NULL",
      name: :index_b_params_on_email_trgm,
      algorithm: :concurrently, if_not_exists: true

    add_index :customer_contacts, :bike_id,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :customer_contacts, :bike_id,
      algorithm: :concurrently, if_exists: true

    remove_index :b_params, name: :index_b_params_on_email_trgm,
      algorithm: :concurrently, if_exists: true
  end
end
