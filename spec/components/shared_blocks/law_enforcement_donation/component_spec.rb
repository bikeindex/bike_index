# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::LawEnforcementDonation::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed, name: "Officer Friendly") }
  let(:component) { render_inline(described_class.new(current_user: user)) }

  it "opens on load, naming the user and their unpaid organization" do
    FactoryBot.create(:organization_role_claimed, user:,
      organization: FactoryBot.create(:organization, kind: "law_enforcement", name: "Gotham PD"))

    modal = component.css("dialog#donateMessageModal")
    expect(modal.first["data-ui--modal-open-on-connect-value"]).to eq "true"
    expect(modal.text).to include "Thanks for using Bike Index!"
    expect(modal.text).to include "Hello Officer Friendly,"
    expect(modal.text).to include "agencies like Gotham PD donate"
    expect(modal.css("a[href^='mailto:']").text).to eq "support@bikeindex.org"
  end

  it "falls back when there's no unpaid law enforcement organization" do
    expect(component.text).to include "agencies like your organization donate"
  end
end
