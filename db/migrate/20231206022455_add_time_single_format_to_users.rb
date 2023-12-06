class AddTimeSingleFormatToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :time_single_format, :boolean, default: false
  end
end
