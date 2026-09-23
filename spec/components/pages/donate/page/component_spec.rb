# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::Page::Component, type: :component do
  let(:options) { {recovery_displays: [], initial_amount:, current_user:, referral_source: "newsletter"} }
  let(:initial_amount) { nil }
  let(:current_user) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "defaults to a monthly Plus membership" do
    expect(component).to have_css("#donate-cadence-monthly[checked]")
    expect(component).to have_css("form[action='/membership'] input[name='membership[level]'][value='plus'][checked]")
    expect(component).to have_css("form[action='/membership'] input[name='referral_source'][value='newsletter']", visible: :all)
    expect(component).to have_button("Become a member — $9.99/month", count: 2)
    expect(component).to have_css("input[name='payment[amount_cents]'][value='5000'][checked]")
    expect(component).to have_css("input[type='hidden'][name='payment[amount_cents]'][disabled]", visible: :all)
    expect(component).to have_css("img[src='#{described_class::WALL_PHOTOS.first}']", count: 1)
  end

  context "with a preset initial_amount" do
    let(:initial_amount) { "25" }

    it "selects it as a one-time donation" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_css("input[type='radio'][name='payment[amount_cents]'][value='2500'][checked]")
      expect(component).to have_css("input[type='hidden'][name='payment[amount_cents]'][disabled]", visible: :all)
      expect(component).to have_button("Donate $25", count: 2)
    end
  end

  context "with a custom initial_amount" do
    let(:initial_amount) { "500" }

    it "fills the other amount" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_no_css("input[type='radio'][name='payment[amount_cents]'][checked]")
      expect(component).to have_css("input[type='hidden'][name='payment[amount_cents]'][value='50000']:not([disabled])", visible: :all)
      expect(component).to have_field(placeholder: "Other amount", with: "500")
      expect(component).to have_button("Donate $500", count: 2)
    end
  end

  context "with a member" do
    let(:current_user) { FactoryBot.create(:user) }
    before { FactoryBot.create(:membership, user: current_user) }

    it "links to their membership instead of a monthly form" do
      expect(component).to have_css("#donate-cadence-one-time[checked]")
      expect(component).to have_no_css("form[action='/membership']")
      expect(component).to have_link("Manage your membership", href: "/membership/edit")
      expect(component).to have_css("input[name='payment[email]'][value='#{current_user.email}']", visible: :all)
      expect(component).to have_button("Donate $50", count: 2)
    end
  end

  context "with recovery displays" do
    let(:recovery_display) { FactoryBot.create(:recovery_display, quote_by: "Sandy") }
    let(:options) { {recovery_displays: [recovery_display, FactoryBot.create(:recovery_display)]} }
    before do
      recovery_display.photo_processed.attach(io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
        filename: "bike.jpg", content_type: "image/jpeg")
    end

    it "shows only the stories with a photo" do
      expect(component).to have_css("li img", count: 1)
      expect(component).to have_text("Sandy")
    end
  end
end
