# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::PhoneDisplay::Component, type: :component do
  let(:phone) { "999 999 9999" }
  let(:options) { {phone:} }
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance).to_html.strip }

  it "renders a tel link, styled as a link by default" do
    expect(instance.render?).to be_truthy
    expect(component).to eq '<a class="twlink tw:font-mono" href="tel:999-999-9999">999-999-9999</a>'
  end

  context "with a country code" do
    let(:phone) { "+91 8041505583" }
    it "renders the country code" do
      expect(component).to eq '<a class="twlink tw:font-mono" href="tel:+91-804-150-5583">+91-804-150-5583</a>'
    end
  end

  context "with an extension" do
    let(:phone) { "+11 121 1111 x2929222" }
    it "pauses before the extension in the link" do
      expect(component).to eq '<a class="twlink tw:font-mono" href="tel:+11-121-1111 ; 2929222">+11-121-1111 x 2929222</a>'
    end
  end

  context "skip_link" do
    let(:options) { {phone:, skip_link: true} }
    it "renders the number without a link, and without twlink" do
      expect(component).to eq '<span class="tw:font-mono">999-999-9999</span>'
    end

    context "with html in the extension" do
      let(:phone) { "777 7777777 x<script>alert(1)</script>" }
      it "escapes it" do
        expect(component).to eq '<span class="tw:font-mono">777-777-7777 x &lt;script&gt;alert(1)&lt;/script&gt;</span>'
      end
    end
  end

  context "no phone" do
    let(:phone) { nil }
    it "does not render" do
      expect(instance.render?).to be_falsey
      expect(component).to eq ""
    end
  end

  context "unparseable phone" do
    let(:phone) { "+1" }
    it "does not render" do
      expect(instance.render?).to be_falsey
      expect(component).to eq ""
    end
  end
end
