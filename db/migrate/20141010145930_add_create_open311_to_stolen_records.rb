class AddCreateOpen311ToStolenRecords < ActiveRecord::Migration
  def change
    add_column :stolen_records, :create_open311, :boolean, default: false, null: false
  end
end
