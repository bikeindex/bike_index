require "rails_helper"

RSpec.describe OrganizedHelper, type: :helper do
  describe "organized bike display" do
    let(:bike) { FactoryBot.create(:creation_organization_bike) }
    let(:target_text) do
      "<span>#{bike.frame_colors.first} <strong>#{bike.mnfg_name}</strong></span>"
    end
    it "renders" do
      expect(organized_bike_text).to be_nil
      expect(organized_bike_text(bike)).to eq target_text
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

  describe "status_display" do
    it "renders text-success" do
      expect(status_display("current")).to eq "<span class=\"text-success\">current</span>"
      expect(status_display("Current")).to eq "<span class=\"text-success\">Current</span>"
    end
    context "retrieved" do
      it "is blue" do
        expect(status_display("retrieved_by_owner")).to eq "<span class=\"text-info\">retrieved by owner</span>"
        expect(status_display("Retrieved")).to eq "<span class=\"text-info\">Retrieved</span>"
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
end
