# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::ResultViewSelect::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {result_view:} }
  let(:result_view) { nil }

  it "renders a radio for each view" do
    expect(component).to have_css "input[type='radio'][name='search_result_view']", count: 2, visible: :all
    expect(component).to have_css "input[value='bike_box'][checked]", visible: :all
  end

  context "thumbnail" do
    let(:result_view) { "thumbnail" }

    it "checks thumbnail" do
      expect(component).to have_css "input[value='thumbnail'][checked]", visible: :all
    end
  end
end
