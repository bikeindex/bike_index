class AddProofOfOwnershipToBikes < ActiveRecord::Migration
  def change
    add_column :stolenRecords, :proof_of_ownership, :boolean
  end
end
