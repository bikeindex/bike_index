class AddUniqueIndexOnEmailDomainsDomain < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    soft_delete_duplicate_domains

    add_index :email_domains, :domain,
      unique: true,
      where: "deleted_at IS NULL",
      name: :index_email_domains_on_domain_unique,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :email_domains, name: :index_email_domains_on_domain_unique,
      algorithm: :concurrently, if_exists: true
  end

  private

  def soft_delete_duplicate_domains
    execute(<<~SQL)
      UPDATE email_domains
      SET deleted_at = NOW()
      WHERE deleted_at IS NULL
        AND id NOT IN (
          SELECT MIN(id)
          FROM email_domains
          WHERE deleted_at IS NULL
          GROUP BY domain
        )
    SQL
  end
end
