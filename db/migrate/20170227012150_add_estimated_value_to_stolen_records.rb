class AddEstimatedValueToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :estimated_value, :integer
  end
end
