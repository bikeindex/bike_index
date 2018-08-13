class AddOrganizationToBParam < ActiveRecord::Migration
  def change
    add_reference :b_params, :organization, index: true
  end
end
