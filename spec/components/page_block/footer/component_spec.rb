# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Footer::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:instance) { described_class.new(current_user: nil, skip_facebook:) }
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:skip_facebook) { false }
  let(:pixel_id) { PageBlock::Footer::Component::FACEBOOK_PIXEL_ID }

  it "renders the footer and the facebook pixel" do
    expect(component).to have_css "footer.primary-footer"
    expect(component.to_html).to include(pixel_id)
    # The pixel id must be emitted as raw JS; HTML-escaping the quotes to &quot;
    # produces a SyntaxError inside the inline <script> (entities aren't decoded there).
    expect(component.to_html).to include(%(fbq('init', "#{pixel_id}")))
    expect(component.to_html).to_not include("&quot;")
  end

  # One cached render serves every page, so an action would send the language switch to
  # whichever page filled the cache
  it "renders the locale form without an action" do
    form = component.css("form.locale-form").first
    expect(form.attributes).to_not have_key("action")
    expect(form["data-controller"]).to eq "page-block--locale-select"
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
      nl = I18n.with_locale(:nl) { with_request_url("/") { render_inline(described_class.new(current_user: nil, skip_facebook:)) } }.to_html
      expect(en).to include("Privacy policy")
      expect(nl).to_not include("Privacy policy")
    end
  end
end
