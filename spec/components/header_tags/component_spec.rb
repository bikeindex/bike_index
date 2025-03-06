# frozen_string_literal: true

require "rails_helper"

RSpec.describe HeaderTags::Component, type: :component do
  let(:options) { {page_title:, page_obj:, controller_name:, controller_namespace:, action_name:} }
  let(:page_title) { nil }
  let(:page_obj) { nil }
  let(:controller_namespace) { nil }
  let(:action_name) { "index" }
  let(:component) { render_inline(described_class.new(**options)) }

  context "welcome index" do
    let(:controller_name) { "welcome" }
    it "renders" do
      expect(component).to be_present
      pp component
    end
  end
end
