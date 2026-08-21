# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Organizations::Index::Filters::Component, type: :component do
  let(:component) do
    with_request_url("/admin/organizations?search_kind=bike_shop&search_pos=lightspeed_pos") do
      render_inline(described_class.new(search_paid: false))
    end
  end

  def entry_query(text, param)
    href = component.css("a").find { |link| link.text.squish == text }&.attr("href")
    Rack::Utils.parse_nested_query(URI.parse(href).query.to_s)[param]
  end

  # POS had no clearing entry, and its entries link to the value they apply - so an active
  # POS filter was only removable by editing the URL
  it "offers a clearing entry for each filter, which leaves the other filters alone" do
    expect(entry_query("All POS", "search_pos")).to be_nil
    expect(entry_query("All POS", "search_kind")).to eq "bike_shop"

    expect(entry_query("All Kinds", "search_kind")).to be_nil
    expect(entry_query("All Kinds", "search_pos")).to eq "lightspeed_pos"
  end
end
