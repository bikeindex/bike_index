# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::Register do
  let(:b_param) { BParam.new(origin: "registration_flow", params: {bike: bike_params}.as_json) }
  let(:bike_params) { {owner_email: "owner@example.com", manufacturer_id: 12} }

  describe "b_param_for" do
    let(:user) { nil }

    it "creates a registration, keeping only a valid Bike status" do
      b_param = described_class.b_param_for(user:, status: "status_stolen", organization_id: 12)
      expect(b_param).to have_attributes(origin: "registration_flow", creator_id: nil,
        status: "status_stolen", creation_organization_id: 12)

      expect(described_class.b_param_for(user:, status: "stolen").bike["status"]).to be_nil
    end

    context "with a blank registration's token" do
      let!(:blank_b_param) { BParam.create(origin: "registration_flow") }

      it "reuses it" do
        expect {
          expect(described_class.b_param_for(user:, token_id: blank_b_param.id_token)).to eq blank_b_param
        }.to_not change(BParam, :count)
      end

      context "once step 1 is submitted" do
        let!(:blank_b_param) do
          BParam.create(origin: "registration_flow", params: {bike: {manufacturer_id: 12}}.as_json)
        end

        it "creates a fresh registration" do
          expect {
            expect(described_class.b_param_for(user:, token_id: blank_b_param.id_token)).to_not eq blank_b_param
          }.to change(BParam, :count).by 1
        end
      end
    end

    context "signed in" do
      let(:user) { FactoryBot.create(:user_confirmed) }

      it "sets the creator and prefills owner_email" do
        expect(described_class.b_param_for(user:)).to have_attributes(creator_id: user.id,
          owner_email: user.email)
      end

      context "reusing a blank registration" do
        let!(:blank_b_param) { BParam.create(origin: "registration_flow") }

        it "prefills owner_email onto it" do
          expect(described_class.b_param_for(user:, token_id: blank_b_param.id_token)).to eq blank_b_param
          expect(blank_b_param.reload.owner_email).to eq user.email
          # A prefilled email doesn't mark step 1 submitted
          expect(described_class.permitted_step(blank_b_param, "2")).to eq "1"
        end
      end
    end
  end

  describe "save_step_2" do
    let(:b_param) { BParam.create(origin: "registration_flow", params: {bike: bike_params}.as_json) }
    let(:save) { ->(fields) { described_class.save_step_2(b_param, user: nil, image: nil, bike_params: fields) } }

    it "stores absent serials and marks the details completed" do
      save.call("serial_number" => "unknown", "status" => "status_with_owner")
      expect(b_param.reload.bike["serial_number"]).to eq "unknown"
      expect(b_param.details_completed?).to be_truthy

      save.call("serial_number" => "made_without_serial", "status" => "status_with_owner")
      expect(b_param.reload.bike["serial_number"]).to eq "made_without_serial"
    end

    it "keeps saved values over blanks - except colors, where blank removes" do
      color = FactoryBot.create(:color)
      save.call("frame_size_number" => "56", "frame_size_unit" => "cm",
        "secondary_frame_color_id" => color.id.to_s, "status" => "status_with_owner")
      expect(b_param.reload.bike["frame_size_unit"]).to eq "cm"
      expect(b_param.bike["secondary_frame_color_id"]).to eq color.id.to_s

      save.call("frame_size" => "m", "frame_size_unit" => "in", "secondary_frame_color_id" => "")
      expect(b_param.reload.bike["frame_size"]).to eq "m"
      expect(b_param.bike["frame_size_unit"]).to eq "cm" # unit without a number isn't overwritten
      expect(b_param.bike["secondary_frame_color_id"]).to be_blank
    end
  end

  describe "permitted_step" do
    it "allows steps 1 and 2 once step 1 is submitted" do
      expect(described_class.permitted_step(b_param, nil)).to eq "2"
      expect(described_class.permitted_step(b_param, "1")).to eq "1"
      expect(described_class.permitted_step(b_param, "finished")).to eq "2"
    end

    context "step 1 not submitted" do
      let(:bike_params) { {owner_email: "prefilled@example.com"} }

      it "clamps to step 1 - a prefilled email isn't a submission" do
        expect(described_class.permitted_step(b_param, "2")).to eq "1"
      end
    end

    context "bike created" do
      let(:b_param) do
        BParam.new(origin: "registration_flow", created_bike_id: 42, params: {bike: bike_params}.as_json)
      end

      it "clamps to finished" do
        expect(described_class.permitted_step(b_param, "1")).to eq "finished"
      end
    end

    context "details completed without a creator" do
      let(:b_param) do
        BParam.new(origin: "registration_flow",
          params: {details_completed: true, bike: bike_params}.as_json)
      end

      it "clamps to finished - awaiting the email confirmation" do
        expect(described_class.creator_available?(b_param)).to be_falsey
        expect(described_class.permitted_step(b_param, "2")).to eq "finished"
      end

      context "with a creator" do
        let(:b_param) do
          BParam.new(origin: "registration_flow", creator_id: 42,
            params: {details_completed: true, bike: bike_params}.as_json)
        end

        it "stays browsable - update creates the bike instead" do
          expect(described_class.creator_available?(b_param)).to be_truthy
          expect(described_class.permitted_step(b_param, "2")).to eq "2"
        end
      end
    end
  end
end
