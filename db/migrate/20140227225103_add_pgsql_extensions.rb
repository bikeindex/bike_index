class AddPgsqlExtensions < ActiveRecord::Migration
  def up
    execute "CREATE EXTENSION fuzzystrmatch;"
  end

  def down
    execute "DROP EXTENSION fuzzystrmatch;"
  end
end
