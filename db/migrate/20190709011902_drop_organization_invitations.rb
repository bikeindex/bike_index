class DropOrganizationInvitations < ActiveRecord::Migration
  def change
    drop_table :organization_invitations
  end
end
