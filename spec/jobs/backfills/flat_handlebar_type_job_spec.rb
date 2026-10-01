require "rails_helper"

RSpec.describe Backfills::FlatHandlebarTypeJob, type: :job do
  describe "perform" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:b_param) { FactoryBot.create(:b_param) }
    let!(:b_param_created) { FactoryBot.create(:b_param, created_bike_id: bike.id) }
    let!(:b_param_drop_bar) { FactoryBot.create(:b_param) }
    let(:flat_params) { {"bike" => {"owner_email" => "bike_owner@bikeindex.org", "handlebar_type" => "flat"}} }
    let(:drop_bar_params) { {"bike" => {"owner_email" => "bike_owner@bikeindex.org", "handlebar_type" => "drop_bar"}} }
    before do
      BParam.where(id: [b_param.id, b_param_created.id]).update_all(params: flat_params)
      BParam.where(id: b_param_drop_bar.id).update_all(params: drop_bar_params)
    end

    it "moves unfinished flat b_params to horizontal" do
      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(b_param.reload.params["bike"]).to eq flat_params["bike"].merge("handlebar_type" => "horizontal")
      expect(b_param_created.reload.params).to eq flat_params
      expect(b_param_drop_bar.reload.params).to eq drop_bar_params
    end
  end
end
