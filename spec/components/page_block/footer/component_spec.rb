# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Footer::Component, type: :component do
  let(:instance) { described_class.new(current_user: nil, skip_facebook:) }
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
end
