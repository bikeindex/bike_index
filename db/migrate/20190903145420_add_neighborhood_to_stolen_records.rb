class AddNeighborhoodToStolenRecords < ActiveRecord::Migration[4.2]
  def change
    add_column :stolen_records, :neighborhood, :string
  end
end
