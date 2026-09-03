class AddLocationStrToRecoveryDisplay < ActiveRecord::Migration[8.0]
  def change
    add_column :recovery_displays, :location_string, :string
  end
end
