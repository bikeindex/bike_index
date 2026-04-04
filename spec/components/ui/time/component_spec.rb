# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Time::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {time:, format:} }
  let(:time) { Time.utc(2024, 1, 15, 14, 30, 0) }
  let(:format) { nil }

  describe "#render?" do
    context "when time is present" do
      it "renders the component" do
        expect(component).to have_css("span")
      end
    end

    context "when time is nil" do
      let(:time) { nil }

      it "does not render" do
        expect(component).to_not have_css("span")
      end
    end
  end

  describe "rendering content" do
    context "with localize_time format" do
      let(:format) { :localize_time }

      it "renders the time content" do
        expect(component).to have_content("2024-01-15T14:30:00+0000")
        expect(component).to have_css("span.localizeTime")
        expect(component).to_not have_css("span.preciseTime")
      end
    end

    context "with localize_time_precise format" do
      let(:format) { :localize_time_precise }

      it "renders the time content" do
        expect(component).to have_content("2024-01-15T14:30:00+0000")
        expect(component).to have_css("span.localizeTime")
        expect(component).to have_css("span.preciseTime")
      end
    end

    context "with default format (nil)" do
      let(:format) { nil }

      it "defaults to localize_time format" do
        expect(component).to have_content("2024-01-15T14:30:00+0000")
      end
    end

    context "with invalid format" do
      let(:format) { :invalid_format }

      it "defaults to localize_time format" do
        expect(component).to have_content("2024-01-15T14:30:00+0000")
      end
    end
  end
end
