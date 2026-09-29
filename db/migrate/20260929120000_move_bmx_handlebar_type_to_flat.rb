class MoveBmxHandlebarTypeToFlat < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE bikes SET handlebar_type = 0 WHERE handlebar_type = 1"
    execute "UPDATE bike_versions SET handlebar_type = 0 WHERE handlebar_type = 1"
    # An unfinished registration would raise on the removed enum value when it's created
    execute <<~SQL
      UPDATE b_params SET params = jsonb_set(params, '{bike,handlebar_type}', '"flat"')
      WHERE created_bike_id IS NULL AND params->'bike'->>'handlebar_type' = 'bmx'
    SQL
  end

  def down
  end
end
