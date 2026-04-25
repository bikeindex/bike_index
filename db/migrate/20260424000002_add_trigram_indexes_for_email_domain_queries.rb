class AddTrigramIndexesForEmailDomainQueries < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :email_domains, :domain,
      using: :gin, opclass: :gin_trgm_ops,
      name: :index_email_domains_on_domain_trgm,
      algorithm: :concurrently, if_not_exists: true

    add_index :users, :email,
      using: :gin, opclass: :gin_trgm_ops,
      where: "deleted_at IS NULL",
      name: :index_users_on_email_trgm,
      algorithm: :concurrently, if_not_exists: true

    add_index :bikes, :owner_email,
      using: :gin, opclass: :gin_trgm_ops,
      name: :index_bikes_on_owner_email_trgm,
      algorithm: :concurrently, if_not_exists: true

    add_index :notifications, :message_channel_target,
      using: :gin, opclass: :gin_trgm_ops,
      name: :index_notifications_on_message_channel_target_trgm,
      algorithm: :concurrently, if_not_exists: true

    execute <<~SQL.squish
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_b_params_on_bike_owner_email_trgm
      ON b_params USING gin ((params -> 'bike' ->> 'owner_email') gin_trgm_ops)
    SQL
  end

  def down
    execute "DROP INDEX CONCURRENTLY IF EXISTS index_b_params_on_bike_owner_email_trgm"
    remove_index :notifications, name: :index_notifications_on_message_channel_target_trgm,
      algorithm: :concurrently, if_exists: true
    remove_index :bikes, name: :index_bikes_on_owner_email_trgm,
      algorithm: :concurrently, if_exists: true
    remove_index :users, name: :index_users_on_email_trgm,
      algorithm: :concurrently, if_exists: true
    remove_index :email_domains, name: :index_email_domains_on_domain_trgm,
      algorithm: :concurrently, if_exists: true
  end
end
