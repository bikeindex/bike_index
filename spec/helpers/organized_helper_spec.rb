require "rails_helper"

RSpec.describe OrganizedHelper, type: :helper do
  describe "organized bike display" do
    let(:bike) { FactoryBot.create(:creation_organization_bike) }
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
        "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong><small> cargo bike (front storage)</small><em class=\"small text-warning\"> unregistered</em></span>"
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
  end

  describe "status_display" do
    it "renders text-success" do
      expect(status_display("current")).to eq "<span class=\"text-success\">current</span>"
      expect(status_display("Current")).to eq "<span class=\"text-success\">Current</span>"
    end
    context "retrieved" do
      it "is blue" do
        expect(status_display("retrieved_by_owner")).to eq "<span class=\"text-info\">retrieved by owner</span>"
        expect(status_display("Retrieved")).to eq "<span class=\"text-info\">Retrieved</span>"
        expect(status_display("resolved_otherwise")).to eq "<span class=\"text-info\">resolved </span>"
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

  describe "include_fields" do
    let(:organization) { Organization.new }
    let(:user) { User.new }
    it "does not include" do
      expect(include_field_reg_phone?(organization)).to be_falsey
      expect(include_field_reg_phone?(organization, user)).to be_falsey
      expect(include_field_reg_address?(organization)).to be_falsey
      expect(include_field_reg_address?(organization, user)).to be_falsey
      expect(include_field_extra_registration_number?(organization)).to be_falsey
      expect(include_field_organization_affiliation?(organization, user)).to be_falsey
      # the labels work with or without an organization
      expect(registration_field_label(organization, "extra_registration_number")).to be_nil
      expect(registration_field_label(organization, "reg_address")).to be_nil
      expect(registration_field_label(nil, "reg_phone")).to be_nil
      expect(registration_field_label(nil, "organization_affiliation")).to be_nil
      expect(registration_field_label(nil, "reg_student_id")).to be_nil
      expect(registration_field_label(organization, "reg_sticker")).to be_nil
    end
    context "with enabled features" do
      let(:labels) { {reg_phone: "You have to put this in, jerk", extra_registration_number: "XXXZZZZ", reg_student_id: "PUT in student ID!"}.as_json }
      let(:feature_slugs) { %w[extra_registration_number reg_address reg_phone organization_affiliation reg_student_id reg_sticker] }
      let(:organization) { Organization.new(enabled_feature_slugs: feature_slugs, registration_field_labels: labels) }
      it "includes" do
        expect(include_field_reg_phone?(organization)).to be_truthy
        expect(include_field_reg_phone?(organization, user)).to be_truthy
        expect(include_field_reg_address?(organization)).to be_truthy
        expect(include_field_reg_address?(organization, user)).to be_truthy
        expect(include_field_extra_registration_number?(organization)).to be_truthy
        expect(include_field_organization_affiliation?(organization, user)).to be_truthy
        # And test the labels
        expect(registration_field_label(organization, "extra_registration_number")).to eq "XXXZZZZ"
        expect(registration_field_label(organization, "reg_address")).to be_nil
        expect(registration_field_label(organization, "reg_phone")).to eq labels["reg_phone"]
        expect(registration_field_label(organization, "organization_affiliation")).to be_nil
        expect(registration_field_label(organization, "reg_student_id")).to eq "PUT in student ID!"
        expect(registration_field_label(organization, "reg_sticker")).to be_nil
      end
      context "with user with attributes" do
        let(:user) { User.new(phone: "888.888.8888") }
        it "is falsey" do
          expect(user.phone).to be_present
          expect(organization.additional_registration_fields.include?("reg_phone")).to be_truthy
          expect(include_field_reg_phone?(organization, user)).to be_falsey
          expect(include_field_reg_address?(organization, user)).to be_truthy
          expect(include_field_reg_address?(nil, user)).to be_falsey
          expect(include_field_reg_student_id?(organization, user)).to be_truthy
          expect(include_field_reg_student_id?(organization, user)).to be_truthy
        end
      end
    end
  end
end
