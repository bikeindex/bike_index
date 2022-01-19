class AddExpirationToImpoundConfigurations < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_configurations, :expiration_period_days, :integer
  end
end
