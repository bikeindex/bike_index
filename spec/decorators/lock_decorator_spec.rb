require 'spec_helper'

describe LockDecorator do
  describe 'lock_type_name' do
    it "returns the lock type name other name if present" do
      lock = Lock.new
      lock_type = LockType.new
      allow(lock).to receive(:lock_type).and_return(lock_type)
      allow(lock_type).to receive(:name).and_return("lockity lock")
      expect(LockDecorator.new(lock).lock_type_name).to eq("lockity lock")
    end
  end
end
