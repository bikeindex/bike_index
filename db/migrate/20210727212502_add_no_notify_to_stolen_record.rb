class AddNoNotifyToStolenRecord < ActiveRecord::Migration[5.2]
  def change
    add_column :stolen_records, :no_notify, :boolean, default: false
  end
end
