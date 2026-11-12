# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::YearEnd::Component, type: :component do
  include_context :active_stripe_prices
  let(:options) { {stripe_prices:, referral_source:, initial_amount:} }
  let(:referral_source) { nil }
  let(:initial_amount) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "offers the campaign presets, defaulting to a one-time $100 gift sourced to the campaign" do
    expect(component).to have_css("h1", text: "Make a year-end gift to Bike Index")
    expect(component).to have_text("Our goal is $20,000 by December 31.")
    expect(component).to have_css("#donate-form input[name='payment[amount_cents]'][value='10000'][checked]")
    expect(component).to have_css("#donate-form input[name='payment[referral_source]'][value='eoy-2026']", visible: :all)
    expect(component).to have_button("Donate $100", count: 2)
    expect(component).to have_no_text("Your bike made it home")
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden")
  end

  it "lists the figures and what shipped" do
    expect(component).to have_css("dl > div > dt + dd", text: "1,358")
    expect(component).to have_text("helped 1,358 stolen bikes get home")
    expect(component).to have_text("$1.5M")
    expect(component).to have_text("96,328")
    expect(component).to have_css("h3", text: "E-bike legality checker")
    expect(component).to have_link("Visit the Marketplace", href: "/search/marketplace")
    expect(component).to have_link("See a sneak peek of Bike Book", href: "/bikebook")
    expect(component).to have_css("iframe[inert][title='Meet Bike Book'][src^='/bikebook?vehicle_models=']")
    expect(component).to have_css("iframe[inert][title='Marketplace'][src='/search/marketplace']")
  end

  it "links the major gifts to this page, with their amount" do
    expect(component).to have_css("a[data-amount='500'][href='/donate/year-end?initial_amount=500&source=eoy-2026#donate-form']")
    expect(component).to have_css("a[data-amount='1000']", text: "$1,000")
  end

  context "with a source param that isn't a string" do
    let(:referral_source) { ["eoy-2026-recovered"] }

    it "uses the campaign's source" do
      expect(component).to have_css("#donate-form input[name='payment[referral_source]'][value='eoy-2026']", visible: :all)
      expect(component).to have_no_text("Your bike made it home")
    end
  end

  context "in another currency" do
    let(:currency_enum) { "eur" }

    it "keeps the goal in dollars and the currency on the major gift links" do
      expect(component).to have_text("Our goal is $20,000 by December 31.")
      expect(component).to have_css("a[data-amount='500'][href='/donate/year-end?currency=eur&initial_amount=500&source=eoy-2026#donate-form']", text: "€500")
    end
  end

  context "with a recovered source" do
    let(:referral_source) { "eoy-2026-recovered" }

    it "greets the recovered audience, with the 10% helper open and the source kept" do
      expect(component).to have_css("h1", text: "Your bike made it home. Help the next one get there.")
      expect(component).to have_no_text("helped 1,358 stolen bikes get home")
      expect(component).to have_css("#donate-form input[name='payment[referral_source]'][value='eoy-2026-recovered']", visible: :all)
      expect(component).to have_no_css("[data-ui--collapse-target='content'].tw\\:hidden")
      expect(component).to have_css("[data-controller~='donate--ten-percent'] [aria-live='polite'] [data-donate--ten-percent-target='result']")
    end
  end

  context "with a major gift initial_amount" do
    let(:initial_amount) { "1000" }

    it "marks that gift's tile and the donate buttons" do
      expect(component).to have_css("a[data-amount='1000'][data-active='true']")
      expect(component).to have_button("Donate $1,000", count: 2)
    end
  end
end
