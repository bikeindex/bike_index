require "rails_helper"

RSpec.describe Backfills::BParamParkingNotificationAttrsJob, type: :job do
  let(:instance) { described_class.new }

  describe "scope" do
    let!(:b_param_legacy) { FactoryBot.create(:b_param, params: {"parking_notification" => {"zipcode" => "60647", "state_id" => 1}}) }
    let!(:b_param_new) { FactoryBot.create(:b_param, params: {"parking_notification" => {"postal_code" => "60647"}}) }
    let!(:b_param_no_parking) { FactoryBot.create(:b_param) }

    it "returns only b_params with legacy parking_notification attrs" do
      expect(described_class.scope).to eq([b_param_legacy])
    end
  end

  describe "perform" do
    let(:b_param) do
      FactoryBot.create(:b_param, params: {
        "parking_notification" => {
          "zipcode" => "60647",
          "state_id" => 42,
          "street" => "123 Main St",
          "city" => "Chicago",
          "latitude" => 41.92
        }
      })
    end

    it "renames legacy attributes to new names" do
      instance.perform(b_param.id)
      b_param.reload

      parking_attrs = b_param.params["parking_notification"]
      expect(parking_attrs).to eq({
        "postal_code" => "60647",
        "region_record_id" => 42,
        "street" => "123 Main St",
        "city" => "Chicago",
        "latitude" => 41.92
      })
      expect(parking_attrs).not_to have_key("zipcode")
      expect(parking_attrs).not_to have_key("state_id")
    end

    context "when only zipcode is present" do
      let(:b_param) { FactoryBot.create(:b_param, params: {"parking_notification" => {"zipcode" => "90210"}}) }

      it "renames only zipcode" do
        instance.perform(b_param.id)

        parking_attrs = b_param.reload.params["parking_notification"]
        expect(parking_attrs["postal_code"]).to eq("90210")
        expect(parking_attrs).not_to have_key("zipcode")
      end
    end

    context "when already using new attributes" do
      let(:b_param) { FactoryBot.create(:b_param, params: {"parking_notification" => {"postal_code" => "60647"}}) }

      it "does not update" do
        expect { instance.perform(b_param.id) }.not_to change { b_param.reload.updated_at }
      end
    end
  end
end
