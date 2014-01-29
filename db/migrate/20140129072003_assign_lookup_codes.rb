class AssignLookupCodes < ActiveRecord::Migration
  def up
    User.connection.schema_cache.clear!
    User.reset_column_information

    Bike.where(:xyz_code => nil).find_each do |b|
      xyz = LookupCode.next_code
      b.update_attribute(:xyz_code, xyz)
    end
  end

  def down
    # leave a mesg after the beep
  end
end
