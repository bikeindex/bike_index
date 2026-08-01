class CreateRegistrationSequenceAcknowledgments < ActiveRecord::Migration[8.1]
  def change
    create_table :registration_sequence_acknowledgments do |t|
      # What was agreed to is read off the sequence, which activation freezes, and which
      # is soft-deleted rather than destroyed
      t.references :registration_sequence, index: true
      # The in-flight registration, until the bike takes over as the durable link
      t.references :b_param, index: true
      t.references :bike, index: true
      t.references :user, index: true
      t.string :owner_email

      t.timestamps
    end

    # A registration acknowledges once
    add_index :registration_sequence_acknowledgments, :b_param_id, unique: true,
      where: "b_param_id IS NOT NULL",
      name: "index_registration_sequence_acknowledgments_one_per_b_param"
  end
end
