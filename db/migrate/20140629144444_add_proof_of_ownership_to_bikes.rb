class AddProofOfOwnershipToBikes < ActiveRecord::Migration
  def change
    add_column :stolen_records, :proof_of_ownership, :boolean
  end
end
