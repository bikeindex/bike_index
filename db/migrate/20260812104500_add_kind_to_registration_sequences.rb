class AddKindToRegistrationSequences < ActiveRecord::Migration[8.1]
  # An owner (an organization, or nobody for the template) has one sequence per kind, so
  # every unique guard gains kind. Existing rows are all the e-vehicle kind, which is 0
  def up
    add_column :registration_sequences, :kind, :integer, null: false, default: 0

    remove_index :registration_sequences, name: "index_registration_sequences_one_draft_per_org"
    remove_index :registration_sequences, name: "index_registration_sequences_one_active_per_org"
    remove_index :registration_sequences, name: "index_registration_sequences_one_draft_template"
    remove_index :registration_sequences, name: "index_registration_sequences_one_active_template"

    add_index :registration_sequences, %i[organization_id kind], unique: true,
      where: "start_at IS NULL AND organization_id IS NOT NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_draft_per_org"
    add_index :registration_sequences, %i[organization_id kind], unique: true,
      where: "start_at IS NOT NULL AND end_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_active_per_org"
    add_index :registration_sequences, "(organization_id IS NULL), kind", unique: true,
      where: "organization_id IS NULL AND start_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_draft_template"
    add_index :registration_sequences, "(organization_id IS NULL), kind", unique: true,
      where: "organization_id IS NULL AND start_at IS NOT NULL AND end_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_active_template"
  end

  # Only reversible while every kind is e-vehicle - the restored indexes can't hold a
  # second kind alongside it
  def down
    remove_index :registration_sequences, name: "index_registration_sequences_one_draft_per_org"
    remove_index :registration_sequences, name: "index_registration_sequences_one_active_per_org"
    remove_index :registration_sequences, name: "index_registration_sequences_one_draft_template"
    remove_index :registration_sequences, name: "index_registration_sequences_one_active_template"

    remove_column :registration_sequences, :kind

    add_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NULL AND organization_id IS NOT NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_draft_per_org"
    add_index :registration_sequences, :organization_id, unique: true,
      where: "start_at IS NOT NULL AND end_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_active_per_org"
    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL AND start_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_draft_template"
    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL AND start_at IS NOT NULL AND end_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_active_template"
  end
end
