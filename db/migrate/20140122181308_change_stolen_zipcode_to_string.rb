class ChangeStolenZipcodeToString < ActiveRecord::Migration
  def up
    change_column :stolen_records, :zipcode, :string
  end
  def down
    change_column :stolen_records, :zipcode, :integer
  end
end
