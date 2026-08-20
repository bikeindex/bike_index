require "rails_helper"

RSpec.describe OrganizedHelper, type: :helper do
  describe "organized bike display" do
    let(:bike) { FactoryBot.create(:bike_organized) }
    let(:target_prefix) { "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong>, <small class=\"less-strong\">" }
    it "renders" do
      expect(organized_bike_text).to be_nil
      result = organized_bike_text(bike)
      expect(result).to start_with("#{target_prefix}web ") # origin_display label
      expect(result).to include("Registered with self registration process") # origin_display tooltip
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
      let(:error_class) { UI::Alerts::Base::Component::TEXT_CLASSES[:error] }
      it "is red" do
        expect(status_display("removed_from_bike_index")).to eq "<span class=\"#{error_class}\">removed from bike index</span>"
        expect(status_display("Removed from Bike Index")).to eq "<span class=\"#{error_class}\">Removed from Bike Index</span>"
        expect(status_display("Trashed")).to eq "<span class=\"#{error_class}\">Trashed</span>"
      end
    end
    context "impounded" do
      let(:error_class) { UI::Alerts::Base::Component::TEXT_CLASSES[:error] }
      it "is orange" do
        expect(status_display("impounded")).to eq "<span class=\"#{error_class}\">impounded</span>"
      end
    end
    context "impound_claim" do
      let(:error_class) { UI::Alerts::Base::Component::TEXT_CLASSES[:error] }
      it "info for approved, red for denied" do
        expect(status_display("approved")).to eq "<span class=\"text-info\">approved</span>"
        expect(status_display("claim_approved")).to eq "<span class=\"text-info\">claim approved</span>"
        expect(status_display("denied")).to eq "<span class=\"#{error_class}\">denied</span>"
        expect(status_display("claim_denied")).to eq "<span class=\"#{error_class}\">claim denied</span>"
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
    context "registrations index" do
      let(:controller_name) { "registrations" }
      it "is container-fluid" do
        expect(organized_container).to eq "container-fluid"
      end
    end
    context "bulk_imports index" do
      let(:controller_name) { "bulk_imports" }
      it "is container-fluid" do
        expect(organized_container).to eq "container"
      end
      context "action_name: show" do
        let(:action_name) { "show" }
        it "is container-fluid" do
          expect(organized_container).to eq "container-fluid"
        end
      end
    end
    context "exports index" do
      let(:controller_name) { "exports" }
      it "is container-fluid" do
        expect(organized_container).to eq "container"
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
    context "registrations" do
      let(:controller_name) { "registrations" }
      it "is truthy" do
        expect(organized_include_javascript_pack?).to be_truthy
      end
    end
    context "bikes recoveries" do
      let(:controller_name) { "bikes" }
      let(:action_name) { "recoveries" }
      it "is truthy" do
        expect(organized_container).to eq "container"
        expect(organized_include_javascript_pack?).to be_truthy
      end
    end
  end
end
