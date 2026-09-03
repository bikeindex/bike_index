class AddAcknowledgmentToRegistrationSequences < ActiveRecord::Migration[8.1]
  def change
    # faq_url and acknowledgment_text are the settings shared by every page of a sequence
    add_column :registration_sequences, :faq_url, :string
    add_column :registration_sequences, :acknowledgment_text, :text
    # Soft delete, so an acknowledgment can still read the rules it was given - destroying
    # an organization cascades here, and the record has to outlive that
    add_column :registration_sequences, :deleted_at, :datetime
    add_index :registration_sequences, :deleted_at

    # organization_specific badges a page with the organization's own name; heading is
    # the large text at the top, where title labels the page's rules
    add_column :registration_sequence_pages, :organization_specific, :boolean, default: false, null: false
    add_column :registration_sequence_pages, :heading, :string

    # The one-per-organization guarantees only ever meant live rows
    remove_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NULL AND organization_id IS NOT NULL",
      name: "index_registration_sequences_one_draft_per_org"
    remove_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NOT NULL AND end_at IS NULL",
      name: "index_registration_sequences_one_active_per_org"
    remove_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL",
      name: "index_registration_sequences_single_template"

    add_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NULL AND organization_id IS NOT NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_draft_per_org"
    add_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NOT NULL AND end_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_active_per_org"
    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_single_template"
  end
end
