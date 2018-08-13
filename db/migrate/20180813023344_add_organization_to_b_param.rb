class AddOrganizationToBParam < ActiveRecord::Migration
  def change
    add_reference :b_params, :organization, index: true
    add_column :b_params, :email, :string
  end
end
