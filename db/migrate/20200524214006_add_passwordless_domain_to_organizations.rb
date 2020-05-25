class AddPasswordlessDomainToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :passwordless_user_domain, :string
    add_column :memberships, :created_by_magic_link, :boolean, default: false
  end
end
