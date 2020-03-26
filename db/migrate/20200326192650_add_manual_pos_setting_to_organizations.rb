class AddManualPosSettingToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :manual_pos_setting, :integer
  end
end
