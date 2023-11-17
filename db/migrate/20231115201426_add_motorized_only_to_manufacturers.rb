class AddMotorizedOnlyToManufacturers < ActiveRecord::Migration[6.1]
  def change
    add_column :manufacturers, :motorized_only, :boolean, default: false
  end
end
