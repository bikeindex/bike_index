# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::SearchResults::Container::Component, type: :component do
  let(:component) { render_inline(described_class.new(bikes:, no_results:, result_view:)) }
  let(:bikes) { [FactoryBot.create(:bike, id: 42)] }
  let(:result_view) { nil }
  let(:no_results) { "No Listings exactly matched your search" }

  it "renders the cards, in the cards grid" do
    expect(component.css("ul").first["class"]).to match("grid-cols-")
    expect(component.css("li").count).to eq 1
    expect(component).to_not have_text no_results
  end

  context "result_view :list" do
    let(:result_view) { :list }

    it "renders the rows, in the list's container query" do
      expect(component.css("ul").first["class"]).to match("tw:@container")
    end
  end

  context "no bikes" do
    let(:bikes) { [] }

    it "renders no_results in place of the list" do
      expect(component.css("ul")).to_not be_present
      expect(component).to have_text no_results
    end
  end

  # The public searches reach BikeCard and BikeListItem only through here, and this passes
  # no organization - which is what keeps the org search's badge, its organization_id links
  # and the owner's registration address off a public page. A bike carrying all three.
  context "with a registration of an organization's, listed for sale" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["credibility_badges"])
    end
    let(:bike) do
      FactoryBot.create(:bike_organized, creation_organization: organization,
        address_record: FactoryBot.create(:address_record, :los_angeles, kind: :bike))
    end
    let(:bikes) { [bike] }

    def expect_nothing_the_org_search_adds
      expect(component).to have_link(href: "/bikes/#{bike.id}")
      expect(component).to have_no_text("Registered with")
      expect(component).to have_no_text("Not registered with")
      expect(component).to have_no_text("Los Angeles")
      expect(component.to_html).to_not include("organization_id=")
    end

    it "renders the cards without it" do
      expect_nothing_the_org_search_adds
    end

    context "result_view :list" do
      let(:result_view) { :list }

      it "renders the rows without it" do
        expect_nothing_the_org_search_adds
      end
    end
  end
end
