require 'spec_helper'

describe RemoveExpiredBParamsWorker do
  it { is_expected.to be_processed_in :afterwards }

  it "doesn't fail if bikeParam doesn't exist" do
    expect(RemoveExpiredBParamsWorker.new.perform(494949)).to be_truthy
  end

  it 'removes old bikeParams' do
    bikeParam = FactoryGirl.create(:bikeParam)
    bikeParam.update_attribute :created_at, Time.now - 2.months
    expect do
      RemoveExpiredBParamsWorker.new.perform(bikeParam.id)
    end.to change(BParam, :count).by -1
  end

  it "doesn't delete bikeParams with existing bikes created today" do
    bikeParam = FactoryGirl.create(:bikeParam, created_bike_id: 22)
    expect do
      RemoveExpiredBParamsWorker.new.perform(bikeParam.id)
    end.to change(BParam, :count).by 0
  end
end
