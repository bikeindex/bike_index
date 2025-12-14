class RemoveImageFromRecoveryDisplays < ActiveRecord::Migration[8.0]
  def change
    remove_column :recovery_displays, :image, :string
  end
end
