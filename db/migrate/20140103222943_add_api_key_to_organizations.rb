class AddApiKeyToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :access_token, :string
  end
end
