class RemoveOrganizationIsSuspended < ActiveRecord::Migration[6.1]
  def change
    remove_column :organizations, :is_suspended, :boolean
  end
end
