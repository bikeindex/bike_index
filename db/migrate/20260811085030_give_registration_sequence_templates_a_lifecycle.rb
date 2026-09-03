class GiveRegistrationSequenceTemplatesALifecycle < ActiveRecord::Migration[8.1]
  # The template is drafted, activated and archived like an organization's sequence, so there
  # are many template rows rather than one. The per-organization guards skip them - a NULL
  # organization_id doesn't collide in a unique index - so the template gets its own pair.
  def up
    remove_index :registration_sequences, name: "index_registration_sequences_single_template"

    # The template everyone already clones from is live, so activate it rather than leaving
    # organizations cloning nothing until someone presses Activate
    execute <<~SQL
      UPDATE registration_sequences SET start_at = NOW()
      WHERE organization_id IS NULL AND start_at IS NULL AND deleted_at IS NULL
    SQL

    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL AND start_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_draft_template"
    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL AND start_at IS NOT NULL AND end_at IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_one_active_template"
  end

  # Only reversible while the template is a single row - the index restored below can't hold
  # a second one, whether that's a draft above it or an archived predecessor
  def down
    remove_index :registration_sequences, name: "index_registration_sequences_one_draft_template"
    remove_index :registration_sequences, name: "index_registration_sequences_one_active_template"

    # The old code reads start_at as activated, so leaving it set rolls back to a frozen template
    execute <<~SQL
      UPDATE registration_sequences SET start_at = NULL
      WHERE organization_id IS NULL AND end_at IS NULL AND deleted_at IS NULL
    SQL

    add_index :registration_sequences, "(organization_id IS NULL)", unique: true,
      where: "organization_id IS NULL AND deleted_at IS NULL",
      name: "index_registration_sequences_single_template"
  end
end
