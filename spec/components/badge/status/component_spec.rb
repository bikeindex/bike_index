# frozen_string_literal: true

require "rails_helper"

RSpec.describe Badge::Status::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {status:, kind:} }
  let(:status) { nil }
  let(:kind) { nil }

  it "doesn't renders" do
    expect(component.to_html).not_to include("span")
  end

  context "with status: for_sale" do
    let(:status) { "for_sale" }
    it "renders" do
      expect(component).to have_css("span")
    end
  end
end
