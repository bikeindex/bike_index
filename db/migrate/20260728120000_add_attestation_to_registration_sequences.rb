class AddAttestationToRegistrationSequences < ActiveRecord::Migration[8.1]
  def change
    add_column :registration_sequences, :faq_url, :string
    add_column :registration_sequences, :attestation_text, :text
    add_column :registration_sequence_pages, :organization_specific, :boolean, default: false, null: false
  end
end
