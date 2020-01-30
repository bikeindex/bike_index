class AddPosIntegrationKindToOrganizations < ActiveRecord::Migration[4.2]
  def change
    add_column :organizations, :pos_kind, :integer, default: 0
  end
end
