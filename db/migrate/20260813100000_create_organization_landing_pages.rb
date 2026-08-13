class CreateOrganizationLandingPages < ActiveRecord::Migration[8.1]
  def up
    create_table :organization_landing_pages do |t|
      t.references :organization, null: false, index: {unique: true}
      t.text :body

      t.timestamps
    end

    # Imported with SQL rather than through the model, so backfilled pages have no
    # paper_trail create version - their history starts at the first edit after this
    execute <<~SQL
      INSERT INTO organization_landing_pages (organization_id, body, created_at, updated_at)
      SELECT id, landing_html, NOW(), NOW() FROM organizations
      WHERE landing_html IS NOT NULL AND landing_html <> ''
    SQL
  end

  # organizations.landing_html is left in place, so rolling back loses only the edits
  # made after this migration ran
  def down
    drop_table :organization_landing_pages
  end
end
