class AddPosIntegrationKindToOrganizations < ActiveRecord::Migration
  def change
    add_column :organizations, :pos_kind, :integer, default: 0
  end
end
