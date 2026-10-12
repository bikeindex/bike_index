# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::MyAccount::Memberships::Show::Component, type: :component do
  let(:component) { render_inline(described_class.new(membership:)) }
  let(:membership) { nil }

  it "links to the membership tiers" do
    expect(component).to have_text("You aren't a Bike Index member")
    expect(component).to have_link("See membership tiers", href: "/membership/new")
  end

  context "admin managed" do
    let(:membership) { FactoryBot.create(:membership, level: "plus") }

    it "says it's free" do
      expect(component).to have_text("You're a Plus member")
      expect(component).to have_text("you don't pay for it")
      expect(component).to_not have_link("Manage billing")
    end
  end

  context "stripe managed" do
    let(:membership) { FactoryBot.create(:membership_stripe_managed) }
    let(:stripe_price) { membership.current_stripe_subscription.stripe_price }

    it "renders their price, matching the current price" do
      expect(stripe_price.amount_cents).to eq 499
      expect(component).to have_text("$4.99 per month")
      expect(component).to have_text("You pay the current price for Basic")
      expect(component).to have_link("Manage billing", href: "/membership/edit")
    end

    context "with a higher current price" do
      before do
        stripe_price.update(active: false)
        FactoryBot.create(:stripe_price, amount_cents: 500)
      end

      it "says they pay less" do
        expect(component).to have_text("You pay less than new members. Basic is now $5.00 per month")
      end
    end

    context "with a lower current price" do
      before do
        stripe_price.update(active: false)
        FactoryBot.create(:stripe_price, amount_cents: 450)
      end

      it "says what new members pay" do
        expect(component).to have_text("New Basic members pay $4.50 per month")
      end
    end

    context "with no current price" do
      before { stripe_price.update(active: false) }

      it "skips the comparison" do
        expect(component).to have_text("$4.99 per month")
        expect(component).to_not have_text("new members")
        expect(component).to_not have_text("current price")
      end
    end
  end
end
