class CreateRegistrationSequenceAttestations < ActiveRecord::Migration[8.1]
  def change
    create_table :registration_sequence_attestations do |t|
      # Nullified rather than cascaded if the sequence goes: attestation_text below is
      # a snapshot, so the record still stands on its own
      t.references :registration_sequence, index: true
      # The in-flight registration, until the bike takes over as the durable link
      t.references :b_param, index: true
      t.references :bike, index: true
      t.references :user, index: true
      t.string :owner_email
      t.bigint :acknowledged_page_ids, array: true, default: []
      # Snapshotted, so the record still says what was agreed to if the sequence goes
      t.text :attestation_text
      t.datetime :attested_at, null: false

      t.timestamps
    end

    # A registration attests once
    add_index :registration_sequence_attestations, :b_param_id, unique: true,
      where: "b_param_id IS NOT NULL",
      name: "index_registration_sequence_attestations_one_per_b_param"
  end
end
