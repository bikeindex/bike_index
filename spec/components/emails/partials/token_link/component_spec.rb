require "rails_helper"

RSpec.describe Emails::Partials::TokenLink::Component, type: :component do
  it "renders a link Postmark doesn't track" do
    render_inline(described_class.new(href: "https://bikeindex.org/bikes/1?t=token", text: "View"))
    expect(page).to have_css('a.binx-button[href="https://bikeindex.org/bikes/1?t=token"][data-pm-no-track="true"]', text: "View")
  end
end
