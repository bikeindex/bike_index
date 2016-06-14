class AddLockVisibilityToOrganizationsAndRemoveWantsToBeShown < ActiveRecord::Migration
  def change
    add_column :organizations, :lock_show_on_map, :boolean, default: false, null: false
    remove_column :organizations, :wants_to_be_shown
  end
end
