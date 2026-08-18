# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Alerts::FlashMessage::Component, type: :component do
  let(:component) { render_inline(described_class.new(flash:)) }
  let(:flash) { {notice: "Saved!"} }

  it "renders a dismissable alert for each flash message" do
    expect(component).to have_text("Saved!")
    expect(component).to have_css("button[aria-label='Close']")
  end

  context "with error flash" do
    let(:flash) { {error: "Something broke"} }

    it "renders error alert" do
      expect(component).to have_text("Something broke")
    end
  end

  context "with multiple flash messages" do
    let(:flash) { {notice: "Done", error: "But watch out"} }

    it "renders both alerts" do
      expect(component).to have_text("Done")
      expect(component).to have_text("But watch out")
    end
  end

  context "with non-string flash value" do
    let(:flash) { {notice: true} }

    it "skips non-string values" do
      expect(component.to_html).not_to include("true")
    end
  end

  context "with a hash flash value" do
    let(:url) { "/users/update_password_form_with_reset_token" }
    let(:flash) { {notice: {translation_key: :signed_in, url:}} }

    it "translates the message and links the url" do
      expect(component).to have_text("You're signed in!")
      expect(component).to have_link("set a password to sign in", href: url, class: "twlink-underlined")
    end

    context "round-tripped through the flash cookie" do
      let(:flash) { {"notice" => {"translation_key" => "signed_in", "url" => url}} }

      it "renders the same, the cookie is JSON so keys come back as strings" do
        expect(component).to have_link("set a password to sign in", href: url)
      end
    end
  end

  context "with empty flash" do
    let(:flash) { {} }

    it "renders the container with no alerts, so turbo_streams can target it" do
      expect(component).to have_css("#flash-messages")
      expect(component).not_to have_css("[role='alert']")
    end
  end

  context "with an unknown flash type" do
    let(:flash) { {bogus: "Who knows"} }

    it "raises, from the kind it hands the alert" do
      expect { component }.to raise_error(ArgumentError, /unknown kind/i)
    end
  end
end
