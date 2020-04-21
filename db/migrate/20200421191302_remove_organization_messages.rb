class RemoveOrganizationMessages < ActiveRecord::Migration[5.2]
  def change
    drop_table :organization_messages
  end
end
