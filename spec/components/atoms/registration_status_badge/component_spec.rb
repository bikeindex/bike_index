require "rails_helper"

RSpec.describe Atoms::RegistrationStatusBadge::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "with owner (default)" do
    let(:bike) { FactoryBot.create(:bike) }
    it "shows registered, explained by a tooltip" do
      render_inline(component)
      expect(page).to have_text("Registered")
      expect(page).to have_css("[role=tooltip]", text: "Registered & protected. With its owner (not stolen)", visible: :all)
    end
  end

  context "stolen" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    it "shows stolen" do
      render_inline(component)
      expect(page).to have_text("Stolen")
      expect(page).to have_css("[role=tooltip]", text: "Reported stolen", visible: :all)
    end
  end

  context "abandoned" do
    let(:bike) { FactoryBot.create(:bike, status: "status_abandoned") }
    it "shows abandoned" do
      render_inline(component)
      expect(page).to have_text("Abandoned")
    end
  end

  context "for sale" do
    let(:bike) { FactoryBot.create(:bike, is_for_sale: true) }
    it "shows for sale in a fuchsia badge" do
      render_inline(component)
      expect(page).to have_text("For Sale")
      expect(page).to have_css("span.tw\\:text-fuchsia-800")
    end
  end

  context "override_status" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:component) { described_class.new(bike:, override_status: "for sale") }
    it "shows the passed status rather than the bike's own" do
      render_inline(component)
      expect(page).to have_text("For Sale")
      expect(page).to_not have_text("Stolen")
    end
  end

  context "unregistered" do
    let(:bike) { FactoryBot.create(:bike, status: "unregistered_parking_notification") }
    it "shows unregistered in a pink badge" do
      render_inline(component)
      expect(page).to have_text("Unregistered")
      expect(page).to have_css("span.tw\\:text-pink-400")
    end
  end

  context "impounded" do
    let(:bike) { FactoryBot.create(:impound_record_with_organization).bike.reload }
    it "shows impounded" do
      render_inline(component)
      expect(page).to have_text("Impounded")
    end
  end

  # An impound record with no organization is someone finding it, not impounding it
  context "found" do
    let(:bike) { FactoryBot.create(:impound_record).bike.reload }
    it "shows found" do
      render_inline(component)
      expect(page).to have_text("Found")
    end
  end

  describe ".status_humanized" do
    it "returns the bike's own status" do
      expect(described_class.status_humanized(Bike.new(status: :status_stolen))).to eq "stolen"
    end

    context "skip_with_owner" do
      it "blanks with owner, but keeps a for sale bike's status" do
        expect(described_class.status_humanized(Bike.new, skip_with_owner: true)).to eq ""
        expect(described_class.status_humanized(Bike.new(is_for_sale: true), skip_with_owner: true)).to eq "for sale"
      end
    end
  end

  context "skip_with_owner" do
    let(:component) { described_class.new(bike:, skip_with_owner: true) }

    context "with owner" do
      let(:bike) { FactoryBot.create(:bike) }
      it "renders nothing" do
        expect(render_inline(component).to_html).to be_blank
      end
    end

    context "stolen" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      it "still renders" do
        render_inline(component)
        expect(page).to have_text("Stolen")
      end
    end
  end
end
