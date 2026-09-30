require "rails_helper"

RSpec.describe Backfills::BmxHandlebarTypeJob, type: :job do
  describe "perform" do
    let!(:bike) { FactoryBot.create(:bike) }
    let!(:bike_drop_bar) { FactoryBot.create(:bike, handlebar_type: :drop_bar) }
    let!(:bike_version) { FactoryBot.create(:bike_version) }
    let!(:b_param) { FactoryBot.create(:b_param) }
    let!(:b_param_created) { FactoryBot.create(:b_param, created_bike_id: bike.id) }
    let(:bmx_params) { {"bike" => {"owner_email" => "bike_owner@bikeindex.org", "handlebar_type" => "bmx"}} }
    before do
      Bike.unscoped.where(id: bike.id).update_all(handlebar_type: described_class::BMX_VALUE)
      BikeVersion.unscoped.where(id: bike_version.id).update_all(handlebar_type: described_class::BMX_VALUE)
      BParam.where(id: [b_param.id, b_param_created.id]).update_all(params: bmx_params)
    end

    it "moves bmx to flat" do
      expect(bike.reload.handlebar_type).to be_nil

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(bike.reload.handlebar_type).to eq "flat"
      expect(bike_drop_bar.reload.handlebar_type).to eq "drop_bar"
      expect(bike_version.reload.handlebar_type).to eq "flat"
      expect(b_param.reload.params["bike"]).to eq bmx_params["bike"].merge("handlebar_type" => "flat")
      expect(b_param_created.reload.params).to eq bmx_params
    end
  end
end
