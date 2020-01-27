class SwitchUsersToJsonb < ActiveRecord::Migration[4.2]
  def up
    # Pulled from https://stackoverflow.com/questions/28075479/upgrade-postgresql-json-column-to-jsonb
    change_column :users, :partner_data, "jsonb USING CAST(partner_data AS jsonb)"
    change_column :users, :my_bikes_hash, "jsonb USING CAST(my_bikes_hash AS jsonb)"
  end

  def down
    change_column :users, :partner_data, "json USING CAST(partner_data AS json)"
    change_column :users, :my_bikes_hash, "json USING CAST(my_bikes_hash AS json)"
  end
end
