# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Homepage::Top::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {recoveries_value:, organization_count:, recovery_displays:} }
  let(:recoveries_value) { 11_111_111 }
  let(:organization_count) { nil }
  let(:recovery_displays) { [] }

  it "renders" do
    expect(component).to have_css("div")
    expect(component).to have_text("Cities")
    expect(component).to have_text("The bike registry that works")
  end

  describe "recovery showcase" do
    # The slider swaps the bikePhoto target on every arrow click, so it has to
    # render even with no recoveries to show
    it "renders a placeholder photo and an unhidden slide" do
      expect(component).to have_css("img.bike-photo[data-homepage--recovery-showcase-target='bikePhoto']")
      expect(component).to have_link("Read more recovery stories")
      expect(component.css("li[data-slide-index='0']").attr("class").to_s).to_not include("tw:hidden")
    end

    context "with a recovery display" do
      let(:recovery_display) { FactoryBot.create(:recovery_display) }
      let(:recovery_displays) { [recovery_display] }
      before do
        recovery_display.photo_processed.attach(io: StringIO.new("processed image"),
          filename: "processed.jpg", content_type: "image/jpeg")
      end

      it "photographs the first and hides the read-more slide" do
        expect(component).to have_css("img.bike-photo[src='#{recovery_display.photo_url}']")
        expect(component.css("li[data-slide-index='1']").attr("class").to_s).to include("tw:hidden")
      end
    end
  end

  describe "recoveries_value" do
    it "unit tests for instance methods" do
      expect(instance.send(:recoveries_as_currency)).to eq "$11"
      expect(instance.send(:recoveries_value)).to eq "11"
      expect(instance.send(:recoveries_value_symbol)).to eq "$"
    end
  end
end
