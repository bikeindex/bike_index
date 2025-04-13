require "rails_helper"

RSpec.describe OrganizedHelper, type: :helper do
  describe "organized bike display" do
    let(:bike) { FactoryBot.create(:bike_organized) }
    let(:target_origin) { "<span title=\"Registered with self registration process\">web</span>" }
    let(:target_text) do
      "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong>, <small class=\"less-strong\">#{target_origin}</small></span>"
    end
    it "renders" do
      expect(organized_bike_text).to be_nil
      expect(organized_bike_text(bike)).to eq target_text
      expect(organized_bike_text(bike, skip_creation: true)).to eq "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong></span>"
    end
    context "unregistered" do
      let(:target_text) do
        "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong><small> cargo bike</small><em class=\"small text-warning\"> unregistered</em></span>"
      end
      it "renders with unregistered" do
        bike.cycle_type = "cargo"
        bike.status = "unregistered_parking_notification"
        expect(organized_bike_text(bike)).to eq target_text
      end
    end
    context "deleted" do
      let!(:bike) { FactoryBot.create(:bike, deleted_at: Time.current) }
      let(:target_text) do
        "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong><em class=\"small text-danger\"> removed from Bike Index</em></span>"
      end
      it "renders with deleted" do
        expect(bike.deleted?).to be_truthy
        expect(organized_bike_text(bike)).to eq target_text
      end
    end
  end

  describe "origin_display" do
    let(:target) { "<span title=\"Registration began with incomplete registration, via organization landing page\">landing page</span>" }
    it "renders with title" do
      expect(origin_display("landing page")).to eq target
    end
    context "lightspeed" do
      let(:target) { "<span title=\"Automatically registered by bike shop point of sale (Lightspeed POS)\">Lightspeed</span>" }
      it "renders with title" do
        expect(origin_display("Lightspeed")).to eq target
      end
    end
    context "scanned_sticker" do
      let(:target) { "<span title=\"Registered via sticker\">sticker</span>" }
      let(:ownership) { Ownership.new(origin: "sticker") }
      it "renders with title" do
        expect(ownership.creation_description).to eq "sticker"
        expect(origin_display(ownership.creation_description)).to eq target
      end
    end
  end

  describe "status_display" do
    it "renders text-success" do
      expect(status_display("current")).to eq "<span class=\"text-success\">current</span>"
      expect(status_display("Current")).to eq "<span class=\"text-success\">Current</span>"
      expect(status_display_class("Current")).to eq "text-success"
    end
    it "renders text-warning" do
      expect(status_display("stolen")).to eq "<span class=\"text-warning\">stolen</span>"
      expect(status_display("uncertified_by_trusted_org")).to eq "<span class=\"text-warning\">uncertified by trusted org</span>"
    end
    context "text-info" do
      it "is expected" do
        expect(status_display("retrieved_by_owner")).to eq "<span class=\"text-info\">retrieved by owner</span>"
        expect(status_display("Retrieved")).to eq "<span class=\"text-info\">Retrieved</span>"
        expect(status_display("resolved_otherwise")).to eq "<span class=\"text-info\">resolved</span>"
        expect(status_display("certified_by_trusted_org")).to eq "<span class=\"text-info\">certified by trusted org</span>"
      end
    end
    context "removed_from_bike_index, trashed or Removed from Bike Index" do
      it "is red" do
        expect(status_display("removed_from_bike_index")).to eq "<span class=\"text-danger\">removed from bike index</span>"
        expect(status_display("Removed from Bike Index")).to eq "<span class=\"text-danger\">Removed from Bike Index</span>"
        expect(status_display("Trashed")).to eq "<span class=\"text-danger\">Trashed</span>"
      end
    end
    context "impounded" do
      it "is orange" do
        expect(status_display("impounded")).to eq "<span class=\"text-danger\">impounded</span>"
      end
    end
    context "impound_claim" do
      it "info for approved, red for denied" do
        expect(status_display("approved")).to eq "<span class=\"text-info\">approved</span>"
        expect(status_display("claim_approved")).to eq "<span class=\"text-info\">claim approved</span>"
        expect(status_display("denied")).to eq "<span class=\"text-danger\">denied</span>"
        expect(status_display("claim_denied")).to eq "<span class=\"text-danger\">claim denied</span>"
      end
    end
    context "graduated_notification" do
      it "info for approved, red for denied" do
        expect(status_display("remains registered")).to eq "<span class=\"less-strong\">remains registered</span>"
        expect(status_display("REMAINS registered")).to eq "<span class=\"less-strong\">REMAINS registered</span>"
        expect(status_display("bike Graduated")).to eq "<span class=\"text-info\">bike Graduated</span>"
        expect(status_display_class("bike Graduated")).to eq "text-info"
      end
    end
  end

  describe "organized_container" do
    before do
      allow(view).to receive(:controller_name) { controller_name }
      allow(view).to receive(:action_name) { action_name }
    end
    let(:action_name) { "index" }
    context "locations" do
      let(:controller_name) { "manage" }
      let(:action_name) { "locations" }
      it "is container" do
        expect(organized_container).to eq "container"
      end
    end
    context "users" do
      let(:controller_name) { "users" }
      it "is container" do
        expect(organized_container).to eq "container"
      end
    end
    context "bikes index" do
      let(:controller_name) { "bikes" }
      it "is container-fluid" do
        expect(organized_container).to eq "container-fluid"
      end
    end
    context "parking_notifications" do
      let(:controller_name) { "parking_notifications" }
      it "is container-fluid" do
        expect(organized_container).to eq "container-fluid"
      end
    end
  end

  describe "include_javascript_pack?" do
    before do
      allow(view).to receive(:controller_name) { controller_name }
      allow(view).to receive(:action_name) { action_name }
    end
    let(:controller_name) { "users" }
    let(:action_name) { "index" }
    it "is falsey" do
      expect(organized_include_javascript_pack?).to be_falsey
    end
    context "bikes" do
      let(:controller_name) { "bikes" }
      it "is truthy" do
        expect(organized_include_javascript_pack?).to be_truthy
      end
      context "recoveries" do
        let(:action_name) { "recoveries" }
        it "is truthy" do
          expect(organized_container).to eq "container"
          expect(organized_include_javascript_pack?).to be_truthy
        end
      end
    end
  end

  describe "retrieval_link_url" do
    let(:graduated_notification) { FactoryBot.create(:graduated_notification) }
    it "is present" do
      expect(graduated_notification.marked_remaining_link_token).to be_present
      expect(retrieval_link_url(graduated_notification)).to match(graduated_notification.marked_remaining_link_token)
    end
    context "parking_notification" do
      let(:parking_notification) { FactoryBot.create(:parking_notification) }
      it "is present" do
        expect(parking_notification.retrieval_link_token).to be_present
        expect(retrieval_link_url(parking_notification)).to match(parking_notification.retrieval_link_token)
      end
      context "unregistered" do
        let(:parking_notification) { FactoryBot.create(:parking_notification_unregistered) }
        it "is nil" do
          expect(parking_notification.retrieval_link_token).to be_blank
          expect(retrieval_link_url(parking_notification)).to be_nil
        end
      end
    end
  end

  describe "include_fields" do
    let(:organization) { Organization.new }
    let(:user) { User.new }
    it "does not include" do
      expect(include_field_reg_phone?(organization)).to be_falsey
      expect(include_field_reg_phone?(organization, user)).to be_falsey
      expect(include_field_reg_address?(organization)).to be_falsey
      expect(include_field_reg_address?(organization, user)).to be_falsey
      expect(include_field_reg_extra_registration_number?(organization)).to be_falsey
      expect(include_field_reg_organization_affiliation?(organization, user)).to be_falsey
      # the labels work with or without an organization
      expect(registration_field_label(organization, "extra_registration_number")).to be_nil
      expect(registration_field_label(organization, "reg_address")).to be_nil
      expect(registration_field_label(nil, "reg_phone")).to be_nil
      expect(registration_field_label(nil, "organization_affiliation")).to be_nil
      expect(registration_field_label(nil, "reg_student_id")).to be_nil
      expect(registration_field_label(organization, "reg_bike_sticker")).to be_nil
      expect(registration_field_label(organization, "owner_email")).to be_nil
    end
    context "with enabled features" do
      let(:labels) { {reg_phone: "You have to put this in, jerk", reg_extra_registration_number: "XXXZZZZ", reg_student_id: "PUT in student ID!"}.as_json }
      let(:feature_slugs) { %w[reg_extra_registration_number reg_address reg_phone reg_organization_affiliation reg_student_id reg_bike_sticker] }
      let(:organization) { Organization.new(enabled_feature_slugs: feature_slugs, registration_field_labels: labels) }
      it "includes" do
        expect(include_field_reg_phone?(organization)).to be_truthy
        expect(include_field_reg_phone?(organization, user)).to be_truthy
        expect(include_field_reg_address?(organization)).to be_truthy
        expect(include_field_reg_address?(organization, user)).to be_truthy
        expect(include_field_reg_extra_registration_number?(organization)).to be_truthy
        expect(include_field_reg_organization_affiliation?(organization, user)).to be_truthy
        # And test the labels
        expect(registration_field_label(organization, "reg_extra_registration_number")).to eq "XXXZZZZ"
        expect(registration_field_label(organization, "reg_address")).to be_nil
        expect(registration_field_label(organization, "reg_phone")).to eq labels["reg_phone"]
        expect(registration_field_label(organization, "reg_organization_affiliation")).to be_nil
        expect(registration_field_label(organization, "reg_student_id")).to eq "PUT in student ID!"
        expect(registration_field_label(organization, "reg_bike_sticker")).to be_nil
        expect(registration_field_label(organization, "owner_email")).to be_nil
      end
      context "with user with attributes" do
        let(:user) { User.new(phone: "888.888.8888") }
        it "includes" do
          expect(user.phone).to be_present
          expect(organization.additional_registration_fields.include?("reg_phone")).to be_truthy
          expect(include_field_reg_phone?(organization, user)).to be_falsey
          expect(include_field_reg_address?(organization, user)).to be_truthy
          expect(include_field_reg_address?(nil, user)).to be_falsey
          expect(include_field_reg_student_id?(organization, user)).to be_truthy
          expect(include_field_reg_student_id?(organization, user)).to be_truthy
        end
        context "with user_registration_organization" do
          let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: feature_slugs) }
          let(:registration_info) { {} }
          let(:user) { FactoryBot.create(:user_confirmed) }
          let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, user: user, organization: organization, registration_info: registration_info) }
          it "is falsey with user" do
            expect(include_field_reg_phone?(organization)).to be_truthy
            expect(include_field_reg_phone?(organization, user)).to be_truthy # Purely based on whether user has phone
            expect(include_field_reg_address?(organization)).to be_truthy
            expect(include_field_reg_address?(organization, user)).to be_truthy
            expect(include_field_reg_organization_affiliation?(organization)).to be_truthy
            expect(include_field_reg_organization_affiliation?(organization, user)).to be_truthy
            expect(include_field_reg_student_id?(organization)).to be_truthy
            expect(include_field_reg_student_id?(organization, user)).to be_truthy
          end
          context "with registration_info" do
            let(:user) { FactoryBot.create(:user_confirmed, :in_edmonton, phone: "7773335555", address_set_manually: true) }
            let(:registration_info) { {student_id: "12", organization_affiliation: "staff"} }
            it "is falsey" do
              expect(user.reload.street).to be_present
              expect(include_field_reg_phone?(organization, user)).to be_falsey # Purely based on whether user has phone
              expect(include_field_reg_address?(organization, user)).to be_falsey
              expect(include_field_reg_organization_affiliation?(organization, user)).to be_falsey
              expect(include_field_reg_student_id?(organization, user)).to be_falsey
              # Each bike needs to have these fields - regardless of user_registration_organization
              expect(include_field_reg_extra_registration_number?(organization, user)).to be_truthy
              expect(include_field_reg_bike_sticker?(organization, user)).to be_truthy
            end
          end
        end
      end
      context "owner_email with tags" do
        let(:labels) { {reg_address: "ADDY!!", owner_email: "<code>bikeindex.org</code> email"}.as_json }
        it "includes the thing" do
          expect(registration_field_label(organization, "reg_address")).to eq "ADDY!!"
          expect(registration_field_label(organization, "reg_phone")).to be_nil
          expect(registration_field_label(organization, "owner_email")).to eq "<code>bikeindex.org</code> email"
          expect(registration_field_label(organization, "owner_email", strip_tags: true)).to eq "bikeindex.org email"
        end
      end
      context "stickers" do
        it "includes" do
          expect(include_field_reg_bike_sticker?(organization, user)).to be_truthy
          expect(include_field_reg_bike_sticker?(organization, user, true)).to be_falsey
        end
        context "bike_stickers_user_editable" do
          let(:feature_slugs) { %w[bike_stickers bike_stickers_user_editable reg_bike_sticker] }
          it "includes" do
            expect(include_field_reg_bike_sticker?(organization, user)).to be_truthy
            expect(include_field_reg_bike_sticker?(organization, user, true)).to be_truthy
          end
        end
      end
    end
  end

  describe "registration_field_address_placeholder and registration_address_required_below_helper" do
    it "is complete address" do
      expect(registration_field_address_placeholder).to eq "Street address"
      expect(registration_address_required_below_helper).to be_nil
    end
    context "school" do
      let(:organization) { Organization.new(kind: :school) }
      it "is Campus address" do
        expect(registration_field_address_placeholder(organization)).to eq "Campus mailing address"
        expect(registration_address_required_below_helper(organization)).to be_nil
      end
    end
    describe "reg_address organization" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, kind: :law_enforcement, enabled_feature_slugs: ["reg_address"]) }
      let(:target) { "<span class=\"below-input-help text-warning\">Your full address is required by #{organization.short_name}</span>" }
      it "returns" do
        expect(registration_address_required_below_helper(organization)).to eq target
        expect(registration_field_address_placeholder(organization)).to eq "Street address"
      end
    end
  end
end
