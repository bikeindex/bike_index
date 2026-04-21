# frozen_string_literal: true

require "rails_helper"

RSpec.describe PeriodSelect::Component, type: :component do
  let(:instance) { described_class.new(period:, start_time:, end_time:, **options) }
  let(:options) { {} }
  let(:period) { "all" }
  let(:start_time) { Time.current - 1.year }
  let(:end_time) { Time.current }

  let(:component) { with_request_url("/admin") { render_inline(instance) } }

  it "renders period buttons with active class on the selected period" do
    expect(component).to have_css("#timeSelectionBtnGroup")
    expect(component).to have_css("a.period-select-standard[data-period='hour']")
    expect(component).to have_css("a.period-select-standard.active[data-period='all']")
    expect(component).to have_css("button#periodSelectCustom")
    expect(component).not_to have_css("a[data-period='next_week']")
    expect(component).not_to have_css(".custom-period-selected")
  end

  it "defaults data-nosubmit to false and omits prepend_text" do
    expect(component).to have_css("[data-nosubmit='false']")
    expect(component).not_to have_css(".less-strong")
  end

  context "with skip_submission" do
    let(:options) { {skip_submission: true} }

    it "sets data-nosubmit true" do
      expect(component).to have_css("[data-nosubmit='true']")
    end
  end

  context "with include_future" do
    let(:options) { {include_future: true} }

    it "renders next_week and next_month buttons" do
      expect(component).to have_css("a.period-select-standard[data-period='next_week']")
      expect(component).to have_css("a.period-select-standard[data-period='next_month']")
    end
  end

  context "with prepend_text" do
    let(:options) { {prepend_text: "Impounded during:"} }

    it "renders prepend text" do
      expect(component).to have_css(".less-strong", text: "Impounded during:")
    end
  end

  context "with custom period" do
    let(:period) { "custom" }

    it "marks custom group selected" do
      expect(component).to have_css("#timeSelectionBtnGroup.custom-period-selected")
      expect(component).to have_css("button#periodSelectCustom.active")
      expect(component).to have_css("form#timeSelectionCustom:not(.tw\\:hidden)")
    end
  end

  context "without start_time" do
    it "raises ArgumentError" do
      expect { described_class.new(period:, end_time:) }.to raise_error(ArgumentError, /start_time/)
    end
  end
end
