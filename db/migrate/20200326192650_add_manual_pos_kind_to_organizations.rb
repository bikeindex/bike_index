class AddManualPosKindToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :manual_pos_kind, :integer, default: nil
  end
end
