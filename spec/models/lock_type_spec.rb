require "rails_helper"

RSpec.describe LockType, type: :model do
  it_behaves_like "friendly_slug_findable"

  describe "mnfg_name" do
    it "returns the value of manufacturer_other if manufacturer is other" do
      lock = Lock.new
      other_manufacturer = Manufacturer.new
      allow(other_manufacturer).to receive(:name).and_return("Other")
      allow(lock).to receive(:manufacturer).and_return(other_manufacturer)
      allow(lock).to receive(:manufacturer_other).and_return("Other manufacturer name")
      expect(lock.mnfg_name).to eq("Other manufacturer name")
    end

    it "returns the name of the manufacturer if it isn't other" do
      lock = Lock.new
      manufacturer = Manufacturer.new
      allow(manufacturer).to receive(:name).and_return("Mnfg name")
      allow(lock).to receive(:manufacturer).and_return(manufacturer)
      expect(lock.mnfg_name).to eq("Mnfg name")
    end
  end
end
