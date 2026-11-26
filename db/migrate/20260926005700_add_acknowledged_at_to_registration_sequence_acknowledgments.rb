class AddAcknowledgedAtToRegistrationSequenceAcknowledgments < ActiveRecord::Migration[8.1]
  def change
    add_column :registration_sequence_acknowledgments, :acknowledged_at, :datetime
    # Every existing one was created at the moment of agreement
    reversible do |dir|
      dir.up { execute "UPDATE registration_sequence_acknowledgments SET acknowledged_at = created_at" }
    end

    add_index :registration_sequence_acknowledgments, :b_param_id, where: "acknowledged_at IS NULL",
      name: "index_registration_sequence_acknowledgments_pending"
  end
end
