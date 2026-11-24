class AddPosKindToOrganizationSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :organization_signups, :pos_kind, :integer
  end
end
