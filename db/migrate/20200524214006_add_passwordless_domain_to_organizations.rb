class AddPasswordlessDomainToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :passwordless_user_domain, :string
  end
end
