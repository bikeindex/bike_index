class CreateRegistrationSequencesAndPages < ActiveRecord::Migration[8.1]
  def change
    create_table :registration_sequences do |t|
      t.references :organization, index: true
      t.datetime :start_at
      t.datetime :end_at

      t.timestamps
    end

    # At most one draft (not started) and one active (started, not ended) per
    # organization, and a single global template (no organization)
    add_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NULL AND organization_id IS NOT NULL",
      name: "index_registration_sequences_one_draft_per_org"
    add_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NOT NULL AND end_at IS NULL",
      name: "index_registration_sequences_one_active_per_org"
    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL",
      name: "index_registration_sequences_single_template"

    create_table :registration_sequence_pages do |t|
      t.references :registration_sequence, null: false, index: true
      t.string :title
      t.text :subtitle
      t.text :body
      t.integer :listing_order

      t.timestamps
    end
  end
end
