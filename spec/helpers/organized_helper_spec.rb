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
