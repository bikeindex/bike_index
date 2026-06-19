# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Footer::Component, type: :component do
  let(:instance) { described_class.new(controller_namespace:, controller_name:, current_user: nil, params:) }
  let(:component) { with_request_url("/") { render_inline(instance) } }
  let(:controller_namespace) { nil }
  let(:controller_name) { "welcome" }
  let(:params) { ActionController::Parameters.new }
  let(:pixel_id) { PageBlock::Footer::Component::FACEBOOK_PIXEL_ID }

  it "renders the footer and the facebook pixel" do
    expect(component).to have_css "footer.primary-footer"
    expect(component.to_html).to include(pixel_id)
  end

  describe "skip_facebook?" do
    context "with search_email param" do
      let(:params) { ActionController::Parameters.new(search_email: "test@example.com") }
      it "skips the pixel" do
        expect(component.to_html).to_not include(pixel_id)
      end
    end

    context "with proximity param" do
      let(:params) { ActionController::Parameters.new(proximity: "Chicago") }
      it "skips the pixel" do
        expect(component.to_html).to_not include(pixel_id)
      end
    end

    context "with organized namespace" do
      let(:controller_namespace) { "organized" }
      it "skips the pixel" do
        expect(component.to_html).to_not include(pixel_id)
      end
    end

    context "with organizations controller" do
      let(:controller_name) { "organizations" }
      it "skips the pixel" do
        expect(component.to_html).to_not include(pixel_id)
      end
    end
  end
end
