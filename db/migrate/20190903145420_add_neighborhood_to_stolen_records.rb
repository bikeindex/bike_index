class AddNeighborhoodToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :neighborhood, :string
  end
end
