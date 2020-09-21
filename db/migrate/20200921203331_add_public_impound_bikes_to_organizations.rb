class AddPublicImpoundBikesToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :public_impound_bikes, :boolean, default: false
  end
end
