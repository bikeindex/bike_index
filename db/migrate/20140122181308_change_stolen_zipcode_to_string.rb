class ChangeStolenZipcodeToString < ActiveRecord::Migration
  def up
    change_column :stolenRecords, :zipcode, :string
  end
  def down
    change_column :stolenRecords, :zipcode, :integer
  end
end
