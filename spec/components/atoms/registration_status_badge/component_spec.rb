require "rails_helper"

RSpec.describe Atoms::RegistrationStatusBadge::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "with owner (default)" do
    let(:bike) { FactoryBot.create(:bike) }
    it "shows registered, explained by a tooltip" do
      render_inline(component)
      expect(page).to have_text("Registered")
      expect(page).to have_css("[role=tooltip]", text: "Registered & protected, with its owner (not stolen)", visible: :all)
    end
  end

  context "stolen" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    it "shows stolen" do
      render_inline(component)
      expect(page).to have_text("Stolen")
      expect(page).to have_css("[role=tooltip]", text: "Reported stolen by its owner", visible: :all)
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
    it "shows for sale in a purple badge" do
      render_inline(component)
      expect(page).to have_text("For Sale")
      expect(page).to have_css("span.tw\\:text-purple-700")
    end
  end

  context "override_to_for_sale" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:component) { described_class.new(bike:, override_to_for_sale: true) }
    it "shows for sale for a bike that isn't listed yet" do
      expect(bike.is_for_sale?).to be false
      render_inline(component)
      expect(page).to have_text("For Sale")
    end
  end

  context "unregistered" do
    let(:bike) { FactoryBot.create(:bike, status: "unregistered_parking_notification") }
    it "shows unregistered in a warning (yellow) badge" do
      render_inline(component)
      expect(page).to have_text("Unregistered")
      expect(page).to have_css("span.tw\\:text-amber-700")
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
