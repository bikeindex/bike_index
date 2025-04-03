# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pagination::Component, type: :component do
  let(:options) { {pagy:, data:, page_params:} }
  let(:page_params) { {} }
  let(:data) { {} }
  let(:component) { render_inline(described_class.new(**options)) }

  context "bike pagy" do
    let(:pagy) { Pagy.new(count: 1_384_155, limit: 10, page: 1, max_pages: 100) }

    it "renders" do
      with_request_url "/search/registrations" do
        expect(described_class.new(**options).render?).to be_truthy
        expect(component).to be_present
      end
    end
  end

  context "one page" do
    let(:pagy) { Pagy.new(count: 25, limit: 25, page: 1) }

    it "doesn't render" do
      expect(described_class.new(**options).render?).to be_falsey
    end
  end
end
