class AddAvatarAndIsPaidToOrganization < ActiveRecord::Migration
  def change
    add_column :organizations, :avatar, :string
    add_column :organizations, :is_paid, :boolean, default: false, null: false
  end
end
