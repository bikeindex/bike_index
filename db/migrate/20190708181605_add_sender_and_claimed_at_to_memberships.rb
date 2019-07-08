class AddSenderAndClaimedAtToMemberships < ActiveRecord::Migration
  def change
    add_reference :memberships, :sender, index: true
    add_column :memberships, :claimed_at, :datetime
  end
end
