require 'spec_helper'

describe RemoveExpiredBParamsWorker do
  it { is_expected.to be_processed_in :afterwards }

  it "doesn't fail if b_param doesn't exist" do
    expect(RemoveExpiredBParamsWorker.new.perform(494949)).to be_truthy
  end

  it 'removes old b_params' do
    b_param = FactoryGirl.create(:b_param)
    b_param.update_attribute :created_at, Time.now - 2.months
    expect do
      RemoveExpiredBParamsWorker.new.perform(b_param.id)
    end.to change(BParam, :count).by(-1)
  end

  it "doesn't delete b_params with existing bikes created today" do
    b_param = FactoryGirl.create(:b_param, created_bike_id: 22)
    expect do
      RemoveExpiredBParamsWorker.new.perform(b_param.id)
    end.to change(BParam, :count).by 0
  end
end
