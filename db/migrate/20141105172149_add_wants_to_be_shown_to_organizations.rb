class AddWantsToBeShownToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :wants_to_be_shown, :boolean, default: false, null: false
  end
end
