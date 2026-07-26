class AddUniqueIndexToBikeOrganizations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = :index_bike_organizations_on_bike_id_and_organization_id_unique

  def up
    drop_invalid_index
    # Parallel jobs race past the model's uniqueness validation, so collapse the
    # duplicates they created before the database starts rejecting them
    create_duplicates_table
    keep_permissive_duplicate
    repoint_graduated_notifications
    soft_delete_duplicates
    execute("DROP TABLE duplicate_bike_organizations")

    add_index :bike_organizations, %i[bike_id organization_id],
      unique: true,
      where: "deleted_at IS NULL",
      name: INDEX_NAME,
      algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :bike_organizations, name: INDEX_NAME,
      algorithm: :concurrently, if_exists: true
  end

  private

  # A duplicate created while this runs fails the index build and leaves behind an
  # index that enforces nothing - which if_not_exists would take for a finished job
  def drop_invalid_index
    invalid = select_value(<<~SQL)
      SELECT 1
      FROM pg_index
      INNER JOIN pg_class ON pg_class.oid = pg_index.indexrelid
      WHERE pg_class.relname = '#{INDEX_NAME}' AND NOT pg_index.indisvalid
    SQL
    remove_index(:bike_organizations, name: INDEX_NAME) if invalid.present?
  end

  # Grouping 1.8 million rows is the expensive part, so only do it once.
  # The keeper is the oldest row, which is the one first_or_initialize finds
  def create_duplicates_table
    execute(<<~SQL)
      CREATE TEMP TABLE duplicate_bike_organizations AS
      SELECT id, keeper_id, any_editable
      FROM (
        SELECT id,
          MIN(id) OVER bike_and_organization AS keeper_id,
          BOOL_OR(NOT can_not_edit_claimed) OVER bike_and_organization AS any_editable
        FROM bike_organizations
        WHERE deleted_at IS NULL
        WINDOW bike_and_organization AS (PARTITION BY bike_id, organization_id)
      ) undeleted
      WHERE id != keeper_id
    SQL
  end

  # The organization can edit the bike if any of the duplicates permits it
  def keep_permissive_duplicate
    execute(<<~SQL)
      UPDATE bike_organizations
      SET can_not_edit_claimed = FALSE, updated_at = NOW()
      FROM duplicate_bike_organizations
      WHERE bike_organizations.id = duplicate_bike_organizations.keeper_id
        AND duplicate_bike_organizations.any_editable
        AND bike_organizations.can_not_edit_claimed
    SQL
  end

  # bike_organization_id outlives the row it references, so move the notifications
  # onto the row that's being kept
  def repoint_graduated_notifications
    execute(<<~SQL)
      UPDATE graduated_notifications
      SET bike_organization_id = duplicate_bike_organizations.keeper_id, updated_at = NOW()
      FROM duplicate_bike_organizations
      WHERE graduated_notifications.bike_organization_id = duplicate_bike_organizations.id
    SQL
  end

  # Skips the destroy callback, which would delete the kept row's BikeOrganizationNote
  def soft_delete_duplicates
    execute(<<~SQL)
      UPDATE bike_organizations
      SET deleted_at = NOW(), updated_at = NOW()
      FROM duplicate_bike_organizations
      WHERE bike_organizations.id = duplicate_bike_organizations.id
    SQL
  end
end
