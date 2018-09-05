require "spec_helper"

describe AfterBikeChangeWorker do
  let(:subject) { AfterBikeChangeWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :afterwards }

  it "doesn't fail if the bike doesn't exist" do
    instance.perform(0)
  end

  describe "serialized" do
    let!(:bike) { FactoryGirl.create(:stolen_bike) }
    it "calls the things we expect it to call" do
      ENV["BIKE_WEBHOOK_AUTH_TOKEN"] = "xxxx"
      serialized = instance.serialized(bike)
      expect(serialized[:auth_token]).to eq "xxxx"
      expect(serialized[:bike][:id]).to be_present
      expect(serialized[:bike][:stolen_record]).to be_present
      expect(serialized[:update]).to be_truthy
    end
  end
end
