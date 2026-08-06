# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::Register do
  let(:b_param) { BParam.new(origin: "register_flow", params: {bike: bike_params}.as_json) }
  let(:bike_params) { {owner_email: "owner@example.com", manufacturer_id: 12} }

  describe "b_param_for" do
    let(:user) { nil }

    it "creates a registration, keeping only a valid Bike status" do
      b_param = described_class.b_param_for(user:, status: "status_stolen")
      expect(b_param).to have_attributes(origin: "register_flow", creator_id: nil,
        status: "status_stolen")

      expect(described_class.b_param_for(user:, status: "stolen").bike["status"]).to be_nil
    end

    context "with a blank registration's token" do
      let!(:blank_b_param) { BParam.create(origin: "register_flow") }

      it "reuses it" do
        expect {
          expect(described_class.b_param_for(user:, token_id: blank_b_param.id_token)).to eq blank_b_param
        }.to_not change(BParam, :count)
      end

      context "once step 1 is submitted" do
        let!(:blank_b_param) do
          BParam.create(origin: "register_flow", params: {bike: {manufacturer_id: 12}}.as_json)
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
        let!(:blank_b_param) { BParam.create(origin: "register_flow") }

        it "prefills owner_email onto it" do
          expect(described_class.b_param_for(user:, token_id: blank_b_param.id_token)).to eq blank_b_param
          expect(blank_b_param.reload.owner_email).to eq user.email
          # A prefilled email doesn't mark step 1 submitted
          expect(described_class.permitted_step(blank_b_param, "2", sequence: nil)).to eq "1"
        end
      end
    end
  end

  describe "save_step_2" do
    let(:b_param) { BParam.create(origin: "register_flow", params: {bike: bike_params}.as_json) }
    # user_name unless a test says otherwise - an anonymous registration is for someone else
    let(:save) do
      ->(fields, signed_id = nil, image = nil) do
        described_class.save_step_2(b_param, user: nil, image:, image_signed_id: signed_id,
          bike_params: {"user_name" => "Sarah Rider"}.merge(fields))
      end
    end

    it "stores absent serials, marks the details completed, and keeps saved values over blanks" do
      save.call("serial_number" => "unknown", "status" => "status_with_owner")
      expect(b_param.reload.bike["serial_number"]).to eq "unknown"
      expect(described_class.send(:details_completed?, b_param)).to be_truthy

      save.call("serial_number" => "made_without_serial", "status" => "status_with_owner")
      expect(b_param.reload.bike["serial_number"]).to eq "made_without_serial"

      color = FactoryBot.create(:color)
      save.call("frame_size_number" => "56", "frame_size_unit" => "cm",
        "secondary_frame_color_id" => color.id.to_s, "status" => "status_with_owner")
      expect(b_param.reload.bike["frame_size_unit"]).to eq "cm"
      expect(b_param.bike["secondary_frame_color_id"]).to eq color.id.to_s

      # blank removes a color, but leaves everything else as saved
      save.call("frame_size" => "m", "frame_size_unit" => "in", "secondary_frame_color_id" => "")
      expect(b_param.reload.bike["frame_size"]).to eq "m"
      expect(b_param.bike["frame_size_unit"]).to eq "cm" # unit without a number isn't overwritten
      expect(b_param.bike["secondary_frame_color_id"]).to be_blank
    end

    context "without a user_name" do
      it "saves the details but doesn't complete the step" do
        expect(described_class.save_step_2(b_param, user: nil, image: nil, image_signed_id: nil,
          bike_params: {"frame_size" => "m"})).to be_falsey
        expect(b_param.reload.bike["frame_size"]).to eq "m"
        expect(described_class.send(:details_completed?, b_param)).to be_falsey
        # Not finished, so the flow stays on step 2 rather than redirecting past it
        expect(described_class.finished?(b_param, sequence: nil)).to be_falsey
        expect(described_class.permitted_step(b_param, "2", sequence: nil)).to eq "2"
      end

      context "registering their own bike" do
        let(:user) { FactoryBot.create(:user_confirmed, email: "owner@example.com") }

        it "completes the step" do
          expect(described_class.save_step_2(b_param, user:, image: nil, image_signed_id: nil,
            bike_params: {"frame_size" => "m"})).to be_truthy
          expect(described_class.send(:details_completed?, b_param.reload)).to be_truthy
        end
      end
    end

    # What a submit without JS posts - the field keeps its name until the uploader takes over
    context "with a file rather than a signed id" do
      let(:image) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/bike.jpg"), "image/jpeg") }

      it "stores the upload on the b_param" do
        save.call({"status" => "status_with_owner"}, nil, image)

        expect(b_param.reload.image).to be_present
        expect(b_param.image_signed_id).to be_blank
        # It's a file, so it can't ride along in the params json
        expect(b_param.params.to_json).to_not include "bike.jpg"
      end
    end
  end

  describe "permitted_step" do
    it "allows steps 1 and 2 once step 1 is submitted" do
      expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "2"
      expect(described_class.permitted_step(b_param, "1", sequence: nil)).to eq "1"
      expect(described_class.permitted_step(b_param, "finished", sequence: nil)).to eq "2"
    end

    context "step 1 not submitted" do
      let(:bike_params) { {owner_email: "prefilled@example.com"} }

      it "clamps to step 1 - a prefilled email isn't a submission" do
        expect(described_class.permitted_step(b_param, "2", sequence: nil)).to eq "1"
      end
    end

    context "bike created" do
      let(:b_param) do
        BParam.new(origin: "register_flow", created_bike_id: 42, params: {bike: bike_params}.as_json)
      end

      it "clamps to finished" do
        expect(described_class.permitted_step(b_param, "1", sequence: nil)).to eq "finished"
      end
    end

    context "details completed without a creator" do
      let(:b_param) do
        BParam.new(origin: "register_flow",
          params: {details_completed: true, bike: bike_params}.as_json)
      end

      it "clamps to finished - awaiting the email confirmation" do
        expect(described_class.creator_available?(b_param)).to be_falsey
        expect(described_class.permitted_step(b_param, "2", sequence: nil)).to eq "finished"
      end

      context "with a creator" do
        let(:b_param) do
          BParam.new(origin: "register_flow", creator_id: 42,
            params: {details_completed: true, bike: bike_params}.as_json)
        end

        it "stays browsable - update creates the bike instead" do
          expect(described_class.creator_available?(b_param)).to be_truthy
          expect(described_class.permitted_step(b_param, "2", sequence: nil)).to eq "2"
        end
      end
    end
  end

  describe "e-vehicle acknowledgment" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let(:pages) { sequence.registration_sequence_pages.to_a }
    let(:bike_params) do
      {owner_email: "owner@example.com", manufacturer_id: 12, cycle_type: "e-scooter",
       creation_organization_id: organization.id}
    end
    let(:b_param) do
      BParam.create(origin: "register_flow",
        params: {details_completed: true, bike: bike_params}.as_json)
    end

    describe "registration_sequence" do
      it "is the organization's active sequence" do
        expect(described_class.registration_sequence(b_param)).to eq sequence
        # Two detail steps, a page each and the review
        expect(described_class.total_steps(sequence)).to eq 5
      end

      context "not an e-vehicle" do
        let(:bike_params) { super().merge(cycle_type: "bike") }

        it "is nil - only e-vehicles acknowledge safety rules" do
          expect(b_param.motorized?).to be_falsey
          expect(described_class.registration_sequence(b_param)).to be_nil
          expect(described_class.total_steps(nil)).to eq 2
        end
      end

      context "the organization's sequence is still a draft" do
        let!(:sequence) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

        it "is nil - a draft isn't shown to registrants" do
          expect(sequence).to be_draft
          expect(described_class.registration_sequence(b_param)).to be_nil
        end
      end
    end

    it "opens one page at a time, then the review" do
      expect(pages.count).to eq 2
      # The details are in, so the first safety page is where the flow now stands
      expect(described_class.acknowledged?(b_param, sequence:)).to be_falsey
      expect(described_class.permitted_step(b_param, nil, sequence:)).to eq "3"
      expect(described_class.permitted_step(b_param, "4", sequence:)).to eq "3"
      expect(described_class.page_for_step("3", sequence:)).to eq pages.first
      expect(described_class.page_for_step("review", sequence:)).to be_nil

      expect(described_class.acknowledge_page(b_param, pages.first, checked: %w[1 1])).to be_truthy
      expect(described_class.acknowledged_page_ids(b_param)).to eq([pages.first.id])
      expect(described_class.permitted_step(b_param, nil, sequence:)).to eq "4"
      # Every earlier step stays browsable
      expect(described_class.permitted_step(b_param, "3", sequence:)).to eq "3"
      expect(described_class.permitted_step(b_param, "1", sequence:)).to eq "1"

      described_class.acknowledge_page(b_param, pages.last, checked: %w[1 1])
      expect(described_class.permitted_step(b_param, nil, sequence:)).to eq "review"
      expect(described_class.acknowledged?(b_param, sequence:)).to be_falsey

      expect {
        expect(described_class.save_acknowledgment(b_param, sequence, acknowledged_all: "1")).to be_truthy
      }.to change(RegistrationSequenceAcknowledgment, :count).by 1
      expect(described_class.acknowledged?(b_param, sequence:)).to be_truthy

      # The agreement is its own record, naming who agreed and to which sequence
      acknowledgment = RegistrationSequenceAcknowledgment.last
      expect(acknowledgment).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: b_param.id, owner_email: b_param.owner_email, bike_id: nil,
        acknowledgment_text: sequence.acknowledgment)
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
      expect(acknowledgment.acknowledged_at).to be_within(5).of(Time.current)

      # Without a creator the registration now waits on the confirmation email
      expect(described_class.finished?(b_param, sequence:)).to be_truthy
    end

    it "attests once, even if the review is submitted twice" do
      pages.each { described_class.acknowledge_page(b_param, it, checked: %w[1 1]) }
      described_class.save_acknowledgment(b_param, sequence, acknowledged_all: "1")

      expect {
        expect(described_class.save_acknowledgment(b_param, sequence, acknowledged_all: "1")).to be_truthy
      }.to_not change(RegistrationSequenceAcknowledgment, :count)
    end

    it "refuses a page with any rule unchecked" do
      expect(described_class.acknowledge_page(b_param, pages.first, checked: %w[1])).to be_falsey
      expect(described_class.acknowledge_page(b_param, pages.first, checked: nil)).to be_falsey
      expect(described_class.acknowledge_page(b_param, nil, checked: %w[1 1])).to be_falsey
      expect(described_class.acknowledged_page_ids(b_param)).to eq([])
      expect(described_class.permitted_step(b_param, nil, sequence:)).to eq "3"
    end

    it "refuses an unchecked acknowledgment" do
      pages.each { described_class.acknowledge_page(b_param, it, checked: %w[1 1]) }
      expect {
        expect(described_class.save_acknowledgment(b_param, sequence, acknowledged_all: "0")).to be_falsey
      }.to_not change(RegistrationSequenceAcknowledgment, :count)
      expect(described_class.acknowledged?(b_param, sequence:)).to be_falsey
    end

    context "without a sequence" do
      it "has nothing to acknowledge" do
        expect(described_class.acknowledged?(b_param, sequence: nil)).to be_truthy
        expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "finished"
      end
    end
  end

  describe "send_confirmation_email" do
    let(:b_param) { BParam.create(origin: "register_flow", params: {bike: bike_params}.as_json) }

    it "mints a token and emails it, once per interval" do
      expect(described_class.send_confirmation_email(b_param)).to be_truthy
      expect(b_param.reload.email_confirmation_token).to be_present
      Email::PartialRegistrationJob.drain
      expect(Notification.count).to eq 1

      # Anyone holding the registration's token can ask for a resend, so it's rate limited
      expect(described_class.send_confirmation_email(b_param)).to be_falsey

      sent_at = Time.current - described_class::CONFIRMATION_EMAIL_INTERVAL - 1.minute
      b_param.update(params: b_param.params.merge("email_confirmation_sent_at" => sent_at))
      expect(described_class.send_confirmation_email(b_param)).to be_truthy
    end

    context "confirmed" do
      before { b_param.confirm_email! }

      it "has nothing to prove" do
        expect(described_class.send_confirmation_email(b_param)).to be_falsey
      end
    end

    context "with a creator" do
      before { b_param.update(creator_id: FactoryBot.create(:user).id) }

      it "doesn't need the address proven - the bike can be created now" do
        expect(described_class.confirmation_email_pending?(b_param)).to be_falsey
        expect(described_class.send_confirmation_email(b_param)).to be_falsey
      end
    end
  end
end
