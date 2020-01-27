class AddOrganizationToBParam < ActiveRecord::Migration[4.2]
  def change
    add_reference :b_params, :organization, index: true
    add_column :b_params, :email, :string
  end
end
