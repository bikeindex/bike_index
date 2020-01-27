class DropOrganizationInvitations < ActiveRecord::Migration[4.2]
  def change
    drop_table :organization_invitations
  end
end
