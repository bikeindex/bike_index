# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::ChartOrganizationStatuses::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:time_range) { (Time.current - 1.year)..Time.current }
  let(:options) do
    {
      matching_organization_statuses: OrganizationStatus.none,
      matching_organization_statuses_untimed: OrganizationStatus.none,
      time_range:,
      pos_kind: "all",
      ended: false,
      current: false
    }
  end

  describe "table headers" do
    context "with default pos_kind" do
      it "renders matching statuses headers" do
        expect(component).to have_css("th", text: "Matching statuses at start")
        expect(component).to have_css("th", text: "Matching statuses at end")
      end
    end

    context "with not_no_pos pos_kind" do
      let(:options) { super().merge(pos_kind: "not_no_pos") }

      it "renders active POS headers" do
        expect(component).to have_css("th", text: "Active POS at start")
        expect(component).to have_css("th", text: "Active POS at end")
      end
    end

    context "with with_pos pos_kind" do
      let(:options) { super().merge(pos_kind: "with_pos") }

      it "renders active POS headers" do
        expect(component).to have_css("th", text: "Active POS at start")
        expect(component).to have_css("th", text: "Active POS at end")
      end
    end
  end

  describe "chart visibility" do
    it "renders both charts by default" do
      expect(component).to have_css("h4", text: /POS kinds.*start_at/)
      expect(component).to have_css("h4", text: /POS kinds.*end_at/)
    end

    context "when ended" do
      let(:options) { super().merge(ended: true) }

      it "hides the start_at chart" do
        expect(component).not_to have_css("h4", text: /POS kinds.*start_at/)
        expect(component).to have_css("h4", text: /POS kinds.*end_at/)
      end
    end

    context "when current" do
      let(:options) { super().merge(current: true) }

      it "hides the end_at chart" do
        expect(component).to have_css("h4", text: /POS kinds.*start_at/)
        expect(component).not_to have_css("h4", text: /POS kinds.*end_at/)
      end
    end
  end

  describe "count display" do
    it "renders count cells" do
      expect(component).to have_css("td", minimum: 2)
    end
  end
end
