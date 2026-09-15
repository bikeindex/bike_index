# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Turnstile::Component, type: :component do
  let(:email) { nil }
  let(:component) { render_inline(described_class.new(email:)) }

  def with_keys
    stub_const("Integrations::Turnstile::SITE_KEY", "1x00000000000000000000AA")
    stub_const("Integrations::Turnstile::SECRET_KEY", "1x0000000000000000000000000000000AA")
  end

  # Unconfigured is every environment until the keys are set, and a form declaring the
  # controller still has to work without the widget
  it "renders nothing while it's unconfigured" do
    expect(component.to_html).to be_blank
  end

  context "configured" do
    before { with_keys }

    it "hides the widget until an address worth asking arrives" do
      expect(component).to have_css("[data-shared-blocks--turnstile-target='widget'].tw\\:hidden", visible: :all)
      expect(component).to have_css(".cf-turnstile[data-sitekey='1x00000000000000000000AA']", visible: :all)
    end

    # A browser that never ran the reveal still gets the widget on the re-render, rather
    # than posting without a token forever
    context "submitted with a risky address" do
      let(:email) { "rider@yahoo.com" }

      it "renders the widget shown" do
        expect(component).to have_css("[data-shared-blocks--turnstile-target='widget']", visible: :all)
        expect(component).to_not have_css("[data-shared-blocks--turnstile-target='widget'].tw\\:hidden", visible: :all)
      end
    end
  end
end
