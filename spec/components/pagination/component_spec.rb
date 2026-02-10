# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pagination::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {pagy:, data:, page_params:} }
  let(:page_params) { {} }
  let(:data) { {} }

  context "bike pagy" do
    let(:page) { 1 }
    let(:pagy) { Pagy::Offset.new(count: 1_384_155, limit: 10, page:, max_pages: 100) }

    it "renders without previous" do
      with_request_url "/search/registrations" do
        expect(instance.render?).to be_truthy
        expect(component).to be_present
        expect(component).to_not have_css('a[aria-label="Previous"]')
        expect(component).to have_css('a[aria-label="Next"]')
      end
    end

    context "midrange" do
      let(:page) { 3 }
      it "renders with previous and next" do
        with_request_url "/search/registrations" do
          expect(instance.render?).to be_truthy
          expect(component).to be_present
          expect(component).to have_css('[aria-label="Previous"]')
          expect(component).to have_css('[aria-label="Next"]')
        end
      end
    end
    context "final page" do
      let(:page) { 100 }
      it "renders without next" do
        with_request_url "/search/registrations" do
          expect(instance.render?).to be_truthy
          expect(component).to be_present
          expect(component).to have_css('a[aria-label="Previous"]')
          expect(component).to_not have_css('a[aria-label="Next"]')
        end
      end
    end
  end

  context "one page" do
    let(:pagy) { Pagy::Offset.new(count: 25, limit: 25, page: 1) }

    it "doesn't render" do
      expect(instance.render?).to be_falsey
    end
  end

  context "no pagy" do
    let(:pagy) { nil }
    it "doesn't render" do
      expect(instance.render?).to be_falsey
    end
  end
end
