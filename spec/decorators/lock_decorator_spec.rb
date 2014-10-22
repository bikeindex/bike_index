require 'spec_helper'

describe LockDecorator do
  describe :lock_type_name do 
    it "returns the lock type name other name if present" do 
      lock = Lock.new
      lock_type = LockType.new
      lock.stub(:lock_type).and_return(lock_type)
      lock_type.stub(:name).and_return("lockity lock")
      LockDecorator.new(lock).lock_type_name.should eq("lockity lock")
    end
  end
end
