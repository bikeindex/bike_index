# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::SearchResults::Container::Component, type: :component do
  let(:component) { render_inline(described_class.new(result_view:, no_results:)) { results } }
  let(:bike) { FactoryBot.create(:bike, id: 42) }
  let(:results) { render_inline(Pages::SearchResults::BikeCard::Component.new(bike:)).to_html.html_safe }
  let(:result_view) { nil }
  let(:no_results) { nil }
  let(:default_no_results_text) { "No registrations exactly matched your search" }

  it "renders the cards list" do
    expect(component.css("ul").first["class"]).to match("grid-cols-")
    expect(component.css("li")).to be_present
    expect(component.css("a").first["href"]).to match("/bikes/42")
    expect(component).to_not have_text default_no_results_text
  end

  context "result_view :list" do
    let(:result_view) { :list }

    it "renders the list's classes" do
      expect(component.css("ul").first["class"]).to match("tw:@container")
    end
  end

  context "no results" do
    let(:results) { "" }

    it "renders the no_results text in place of the list" do
      expect(component.css("ul")).to_not be_present
      expect(component).to have_text default_no_results_text
    end

    context "passed no_results" do
      let(:no_results) { "OH NO! There are no results" }

      it "renders it" do
        expect(component.css("ul")).to_not be_present
        expect(component).to have_text no_results
      end
    end
  end
end
