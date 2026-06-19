# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Footer::Component, type: :component do
  let(:instance) { described_class.new(current_user: nil, skip_facebook:, page_id: "welcome_index") }
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:skip_facebook) { false }
  let(:pixel_id) { PageBlock::Footer::Component::FACEBOOK_PIXEL_ID }

  it "renders the footer and the facebook pixel" do
    expect(component).to have_css "footer.primary-footer"
    expect(component.to_html).to include(pixel_id)
  end

  context "with skip_facebook" do
    let(:skip_facebook) { true }
    it "renders the footer without the facebook pixel" do
      expect(component).to have_css "footer.primary-footer"
      expect(component.to_html).to_not include(pixel_id)
    end
  end

  describe "caching", :caching do
    include_context :caching_basic

    # The cached fragment must include the locale in its key, or a request in
    # one language serves the footer cached in another. See ApplicationComponentHelper#cache.
    it "varies the cached fragment by locale" do
      en = with_request_url("/") { render_inline(instance) }.to_html
      nl = I18n.with_locale(:nl) { with_request_url("/") { render_inline(described_class.new(current_user: nil, skip_facebook:, page_id: "welcome_index")) } }.to_html
      expect(en).to include("Privacy policy")
      expect(nl).to_not include("Privacy policy")
    end
  end
end
