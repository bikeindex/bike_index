# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::OrgSignup::Views::Welcome::Component, type: :component do
  let(:component) { render_inline(described_class.new(organization:, current_user:)) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:current_user) { FactoryBot.create(:user_confirmed) }

  it "offers to copy the registration link, and to show its QR code" do
    registration_url = "http://test.host/register/new?organization_id=#{organization.slug}"
    expect(component).to have_text registration_url
    expect(component).to have_css "button[data-ui--copy-button-text-value='#{registration_url}'][title='Copy registration link']"
    expect(component).to have_link "Show QR code", href: "/organizations/#{organization.slug}/qr"
  end
end
