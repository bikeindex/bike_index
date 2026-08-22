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

      it "takes the status onto it, and keeps it when the next link names none" do
        described_class.b_param_for(user:, token_id: blank_b_param.id_token, status: "status_stolen")
        expect(blank_b_param.reload.status).to eq "status_stolen"

        described_class.b_param_for(user:, token_id: blank_b_param.id_token)
        expect(blank_b_param.reload.status).to eq "status_stolen"
      end

      # "false" blanks the address even for a signed-in user, status or no status
      context "signed in, asking for no address" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        let!(:blank_b_param) do
          BParam.create(origin: "register_flow", params: {bike: {owner_email: user.email}}.as_json)
        end

        it "clears it alongside the status it takes" do
          described_class.b_param_for(user:, token_id: blank_b_param.id_token,
            status: "status_stolen", email: "false")

          expect(blank_b_param.reload.owner_email).to be_blank
          expect(blank_b_param.status).to eq "status_stolen"
        end
      end

      context "once step 1 is submitted" do
        let!(:started_b_param) do
          BParam.create(origin: "register_flow", params: {bike: {manufacturer_id: 12, status: "status_with_owner"}}.as_json)
        end

        # Redirecting into a started registration would surprise - RegisterController#show
        # is what goes back to one, by its token
        it "creates a fresh registration" do
          expect {
            expect(described_class.b_param_for(user:, token_id: started_b_param.id_token)).to_not eq started_b_param
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

  describe "discard_extra" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let!(:oldest) do
      FactoryBot.create(:b_param_unfinished_registration, creator: user, updated_at: Time.current - 2.hours)
    end
    let!(:middle) do
      FactoryBot.create(:b_param_unfinished_registration, creator: user, updated_at: Time.current - 1.hour)
    end
    let!(:most_recent) { FactoryBot.create(:b_param_unfinished_registration, creator: user) }

    it "destroys every started registration but the most recent" do
      expect { described_class.discard_extra(user:) }.to change(BParam, :count).by(-2)
      expect(BParam.pluck(:id)).to eq([most_recent.id])
    end

    context "with a confirmation email out on one" do
      before do
        middle.generate_email_confirmation_token!
        middle.update(updated_at: Time.current - 1.hour)
      end

      it "keeps it - the email promises the address it can still finish that registration" do
        expect { described_class.discard_extra(user:) }.to change(BParam, :count).by(-1)
        expect(BParam.pluck(:id)).to match_array([middle.id, most_recent.id])
      end
    end
  end

  describe "assign_organization" do
    let(:b_param) { BParam.create(origin: "register_flow", params: {bike: bike_params}.as_json) }
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { FactoryBot.create(:user_confirmed) }

    it "doesn't assign anything without an organization or a user" do
      described_class.assign_organization(b_param, nil, user: nil)
      expect(b_param.reload.creation_organization_id).to be_blank
      expect(b_param.auto_organization_id).to be_blank
    end

    # Marked assigned so the next request doesn't look the registrant up again
    it "assigns nothing for a user in no organization with no bikes, and says so" do
      described_class.assign_organization(b_param, nil, user:)
      expect(b_param.reload.creation_organization_id).to be_blank
      expect(b_param.auto_organization_id).to be_blank
      expect(b_param.auto_organization_assigned?).to be_truthy

      expect { described_class.assign_organization(b_param, nil, user:) }
        .to_not change { b_param.reload.updated_at }
    end

    context "with a user in one organization" do
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, organization:) }

      it "assigns it, and marks it as the automatic assignment step 2 can drop" do
        described_class.assign_organization(b_param, nil, user:)
        expect(b_param.reload.creation_organization_id).to eq organization.id
        expect(b_param.auto_organization_id).to eq organization.id
        expect(b_param.organization_id).to eq organization.id
      end

      it "doesn't reassign once step 2 dropped it" do
        described_class.assign_organization(b_param, nil, user:)
        described_class.save_step_2(b_param, user:, image: nil, image_signed_id: nil,
          bike_params: {"user_name" => "Sarah Rider"}, register_with_organization: nil)
        expect(b_param.reload.creation_organization_id).to be_blank
        expect(b_param.auto_organization_id).to eq organization.id
        expect(b_param.organization_id).to be_blank

        described_class.assign_organization(b_param, nil, user:)
        expect(b_param.reload.creation_organization_id).to be_blank
      end

      it "takes it back when step 2 is resubmitted with the box checked" do
        described_class.assign_organization(b_param, nil, user:)
        described_class.save_step_2(b_param, user:, image: nil, image_signed_id: nil,
          bike_params: {"user_name" => "Sarah Rider"}, register_with_organization: nil)
        described_class.save_step_2(b_param, user:, image: nil, image_signed_id: nil,
          bike_params: {"user_name" => "Sarah Rider"}, register_with_organization: "1")

        expect(b_param.reload.creation_organization_id).to eq organization.id
        expect(b_param.organization_id).to eq organization.id
      end

      context "with a link naming a different organization" do
        let(:link_organization) { FactoryBot.create(:organization) }

        it "takes the link's, and stops offering to drop it" do
          described_class.assign_organization(b_param, nil, user:)
          described_class.assign_organization(b_param, link_organization, user:)

          expect(b_param.reload.creation_organization_id).to eq link_organization.id
          expect(b_param.auto_organization_id).to be_blank
        end
      end

      context "once the bike exists" do
        it "doesn't assign" do
          b_param.update(created_bike_id: FactoryBot.create(:bike).id)
          described_class.assign_organization(b_param, nil, user:)
          expect(b_param.reload.auto_organization_id).to be_blank
        end
      end
    end

    context "with a user in two organizations" do
      let!(:organization_roles) do
        [organization, FactoryBot.create(:organization)]
          .map { FactoryBot.create(:organization_role_claimed, user:, organization: it) }
      end

      it "doesn't assign either of them" do
        described_class.assign_organization(b_param, nil, user:)
        expect(b_param.reload.creation_organization_id).to be_blank
        expect(b_param.auto_organization_id).to be_blank
      end
    end

    context "with a user whose other bike is registered with an organization" do
      let!(:bike) do
        FactoryBot.create(:bike_organized, :with_ownership_claimed,
          creation_organization: organization, user:)
      end

      it "assigns that organization" do
        described_class.assign_organization(b_param, nil, user:)
        expect(b_param.reload.creation_organization_id).to eq organization.id
        expect(b_param.auto_organization_id).to eq organization.id
      end

      context "and another bike with a second organization" do
        let!(:bike_2) do
          FactoryBot.create(:bike_organized, :with_ownership_claimed,
            creation_organization: FactoryBot.create(:organization), user:)
        end

        it "doesn't assign either of them" do
          described_class.assign_organization(b_param, nil, user:)
          expect(b_param.reload.creation_organization_id).to be_blank
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

  describe "report step" do
    let(:creator) { FactoryBot.create(:user) }
    let(:bike_params) { {owner_email: "owner@example.com", manufacturer_id: 12, status: "status_stolen"} }
    let(:b_param) do
      BParam.create(origin: "register_flow", creator_id: creator.id,
        params: {details_completed: true, bike: bike_params}.as_json)
    end
    let(:report_params) do
      {date: "2026-08-05T14:30", timezone: "America/Chicago", theft_description: "Cut lock",
       police_report_number: "42", locking_description: "U-lock", receive_notifications: "0",
       address_record_attributes: {street: "1 Main St", city: "Chicago", street_2: "Apt 2"}}
    end

    it "comes after step 2, and saves the stolen record the bike is created with" do
      expect(described_class.report_step?(b_param.status)).to be_truthy
      expect(described_class.steps(b_param, sequence: nil).count).to eq 3
      expect(described_class.steps(b_param, sequence: nil)).to eq %w[1 2 report]
      expect(described_class.step_before("report", steps: described_class.steps(b_param, sequence: nil))).to eq "2"
      # Not finished: the theft is still to be reported
      expect(described_class.finished?(b_param, sequence: nil)).to be_falsey
      expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "report"

      expect(described_class.save_report(b_param, report_params:)).to be_truthy
      stolen_attrs = b_param.reload.stolen_attrs
      expect(stolen_attrs).to match(hash_including("theft_description" => "Cut lock",
        "police_report_number" => "42", "locking_description" => "U-lock",
        "receive_notifications" => "0", "street" => "1 Main St", "city" => "Chicago"))
      # A stolen record has no second address line to put it on
      expect(stolen_attrs["street_2"]).to be_blank
      # Entered in Chicago, so 14:30 there rather than wherever the server is
      expect(stolen_attrs["date_stolen"].to_time).to be_within(1).of(Time.parse("2026-08-05T19:30:00 UTC"))

      # Everything's in - the submission that saved it creates the bike
      expect(described_class.send(:report_completed?, b_param)).to be_truthy
      expect(described_class.send(:ready_for_bike?, b_param, sequence: nil)).to be_truthy
    end

    describe "when and where a theft has to answer" do
      # A failed step saves anyway, so the re-render still has everything they entered
      def expect_incomplete(params, error)
        expect(described_class.save_report(b_param, report_params: params)).to be_falsey
        expect(b_param.errors.full_messages.to_sentence).to match error
        expect(b_param.reload.stolen_attrs["theft_description"]).to eq "Cut lock"
        expect(described_class.send(:report_completed?, b_param)).to be_falsey
        expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "report"
      end

      it "rejects a blank date" do
        expect_incomplete(report_params.except(:date), /when it was stolen/)
      end

      # Rather than 500ing on it, or quietly recording the moment they submitted
      it "rejects an unparseable date" do
        expect_incomplete(report_params.merge(date: "2026-13-45T99:99"), /when it was stolen/)
      end

      it "rejects a location with no street" do
        expect_incomplete(report_params.merge(address_record_attributes: {city: "Chicago"}),
          /where it was stolen/)
      end

      it "rejects a location with no city" do
        expect_incomplete(report_params.merge(address_record_attributes: {street: "1 Main St"}),
          /where it was stolen/)
      end

      it "names both when neither is answered" do
        expect_incomplete(report_params.except(:date, :address_record_attributes),
          /when it was stolen.*where it was stolen/m)
      end
    end

    context "the status changes after the report" do
      # Going back to step 2 and picking a different one. user_name: the registration is
      # for an address that isn't the creator's, so step 2 doesn't pass without a name
      def resubmit_step_2(status, **bike_attrs)
        described_class.save_step_2(b_param, user: creator, image: nil, image_signed_id: nil,
          bike_params: {"status" => status, "user_name" => "Sally Rider"}.merge(bike_attrs))
      end

      before { described_class.save_report(b_param, report_params:) }

      it "drops the report the new status has no use for" do
        expect(resubmit_step_2("status_with_owner")).to be_truthy

        # Not just the bike's status: BParam reads it back off the record the report saved
        expect(b_param.reload.status).to eq "status_with_owner"
        expect(b_param.stolen_attrs).to be_blank
        expect(described_class.report_step?(b_param.status)).to be_falsey
        expect(described_class.send(:ready_for_bike?, b_param, sequence: nil)).to be_truthy
      end

      it "asks the other report's questions when it's still a status that reports" do
        resubmit_step_2("status_impounded")

        expect(b_param.reload.status).to eq "status_impounded"
        expect(b_param.stolen_attrs).to be_blank
        # The theft report doesn't stand in for the find, so the step opens again
        expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "report"
      end

      it "keeps the report when the status it was made for doesn't change" do
        resubmit_step_2("status_stolen", "frame_model" => "Marlin 7")

        expect(b_param.reload.stolen_attrs["theft_description"]).to eq "Cut lock"
        expect(described_class.send(:report_completed?, b_param)).to be_truthy
      end
    end

    context "found" do
      let(:bike_params) { super().merge(status: "status_impounded") }

      it "saves the impound record instead, keeping the address nested" do
        expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "report"
        expect(described_class.save_report(b_param, report_params:)).to be_truthy

        impound_attrs = b_param.reload.impound_attrs
        expect(impound_attrs["impounded_at"].to_time).to be_within(1).of(Time.parse("2026-08-05T19:30:00 UTC"))
        expect(impound_attrs["address_record_attributes"]).to match(hash_including("street" => "1 Main St",
          "city" => "Chicago", "street_2" => "Apt 2"))
        expect(b_param.stolen_attrs).to be_blank
      end

      # Asked in its own words, since it isn't a theft being described
      it "asks a find when and where too" do
        expect(described_class.save_report(b_param, report_params: {})).to be_falsey
        expect(b_param.errors.full_messages.to_sentence)
          .to match(/when you found it.*where you found it/m)
        expect(described_class.send(:report_completed?, b_param.reload)).to be_falsey
      end
    end

    context "registered with the owner" do
      let(:bike_params) { super().except(:status) }

      it "has no report to make" do
        expect(described_class.report_step?(b_param.status)).to be_falsey
        expect(described_class.steps(b_param, sequence: nil)).to eq %w[1 2]
        expect(described_class.permitted_step(b_param, "report", sequence: nil)).to eq "2"
      end
    end

    context "without a creator" do
      let(:b_param) do
        BParam.create(origin: "register_flow",
          params: {details_completed: true, bike: bike_params}.as_json)
      end

      it "waits for the confirmation email, and is what's left once it's confirmed" do
        expect(described_class.creator_available?(b_param)).to be_falsey
        # The report can't be filled in yet, so the registration is only waiting on the email
        expect(described_class.finished?(b_param, sequence: nil)).to be_truthy
        expect(described_class.permitted_step(b_param, "report", sequence: nil)).to eq "finished"

        b_param.update(creator_id: creator.id)
        expect(described_class.permitted_step(b_param, nil, sequence: nil)).to eq "report"
      end
    end

    context "with acknowledgment pages" do
      let(:organization) { FactoryBot.create(:organization) }
      let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
      let(:bike_params) do
        super().merge(cycle_type: "e-scooter", creation_organization_id: organization.id)
      end

      it "comes before them" do
        expect(described_class.registration_sequence(b_param)).to eq sequence
        # Two detail steps, the report, a page each and the review
        expect(described_class.steps(b_param, sequence:)).to eq %w[1 2 report 3 4 review]
        expect(described_class.permitted_step(b_param, "3", sequence:)).to eq "report"
        expect(described_class.step_before("3", steps: described_class.steps(b_param, sequence:))).to eq "report"

        described_class.save_report(b_param, report_params:)
        expect(described_class.permitted_step(b_param, nil, sequence:)).to eq "3"
        expect(described_class.steps(b_param, sequence:).index("3")).to eq 3
      end

      context "without a creator" do
        let(:b_param) do
          BParam.create(origin: "register_flow",
            params: {details_completed: true, bike: bike_params}.as_json)
        end

        it "comes after them - the emailed link is clicked once they're acknowledged" do
          pages = described_class.sequence_pages(sequence)
          expect(described_class.steps(b_param, sequence:)).to eq %w[1 2 3 4 review report]
          expect(described_class.permitted_step(b_param, "report", sequence:)).to eq "3"

          pages.each { described_class.acknowledge_page(b_param, it, checked: %w[1 1]) }
          described_class.save_acknowledgment(b_param, sequence, acknowledged_all: "1")
          expect(described_class.finished?(b_param, sequence:)).to be_truthy

          # Confirming the email is what opens the report
          b_param.update(creator_id: creator.id)
          expect(described_class.permitted_step(b_param, nil, sequence:)).to eq "report"
          expect(described_class.step_before("report", steps: described_class.steps(b_param, sequence:))).to eq "2"
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
        expect(described_class.steps(b_param, sequence:).count).to eq 5
      end

      context "not an e-vehicle" do
        let(:bike_params) { super().merge(cycle_type: "bike") }

        it "is nil - the e-vehicle sequence isn't what a bike acknowledges" do
          expect(b_param.motorized?).to be_falsey
          expect(described_class.registration_sequence(b_param)).to be_nil
          expect(described_class.steps(b_param, sequence: nil).count).to eq 2
        end

        context "with the organization's non-e-vehicle sequence" do
          let!(:non_e_vehicle_sequence) do
            FactoryBot.create(:registration_sequence_active, :non_e_vehicle, :with_pages, organization:)
          end

          it "is that sequence" do
            expect(described_class.registration_sequence(b_param)).to eq non_e_vehicle_sequence
            # Two detail steps, a page each and the review
            expect(described_class.steps(b_param, sequence: non_e_vehicle_sequence).count).to eq 5
          end
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
