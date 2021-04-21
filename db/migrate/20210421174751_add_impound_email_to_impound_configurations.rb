class AddImpoundEmailToImpoundConfigurations < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_configurations, :email, :string
  end
end
