# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BikeCell::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bike:, bike_id:, bike_link_path:, search_url:, render_search:} }
  let(:bike) { nil }
  let(:bike_id) { nil }
  let(:bike_link_path) { nil }
  let(:search_url) { nil }
  let(:render_search) { nil }

  context "with a bike" do
    let(:bike) { FactoryBot.create(:bike) }

    it "renders the bike title" do
      expect(component.text).to match(/#{bike.title_string}/)
    end

    context "with bike_link_path" do
      let(:bike_link_path) { "/admin/bikes/#{bike.id}" }

      it "renders a link to the bike" do
        expect(component.css("a[href='#{bike_link_path}']")).to be_present
      end
    end

    context "with bike_link_path set to false" do
      let(:bike_link_path) { false }

      it "does not render a link" do
        expect(component.css("a")).to be_blank
      end
    end
  end

  context "with missing bike" do
    let(:bike_id) { 99999999 }

    it "renders missing bike message" do
      expect(component.text).to match(/Missing bike/)
      expect(component.text).to match(/99999999/)
    end
  end

  context "with render_search" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:render_search) { true }
    let(:search_url) { "/admin/bikes?search_bike_id=#{bike.id}" }

    it "renders search link" do
      expect(component.css("a.display-sortable-link")).to be_present
    end
  end
end
