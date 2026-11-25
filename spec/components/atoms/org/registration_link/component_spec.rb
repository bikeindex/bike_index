# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Org::RegistrationLink::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
  let(:component) { render_inline(described_class.new(organization:)) }
  let(:registration_url) { "http://test.host/register/#{organization.slug}" }
  let(:qr_code_path) { "/register/#{organization.slug}.png" }

  it "offers to copy the link, and to show its QR code, hidden until asked" do
    expect(component).to have_css("h2", text: "Your public registration link")
    expect(component).to have_css("code", text: registration_url)
    expect(component).to have_css("button[data-ui--copy-button-text-value='#{registration_url}']", text: "Copy link")
    expect(component).to have_css("[role=button][aria-expanded=false]", text: "QR code")
    expect(component).to have_text "Registrations from this link are associated with Brakebills."

    qr_panel = component.at_css("[data-ui--collapse-target=content]")
    expect(qr_panel[:class]).to include("tw:hidden!")
    expect(qr_panel.at_css("img")[:src]).to eq qr_code_path
    expect(qr_panel.at_css("a[target=_blank]")[:href]).to eq qr_code_path
  end
end
