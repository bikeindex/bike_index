# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Email::Component, type: :component do
  # No object, so the field renders whatever attribute it's given
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, nil, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, **options)) }
  let(:options) { {} }

  it "renders an email field with both messages hidden" do
    expect(component).to have_css("input.twinput[type='email'][name='user[email]'][data-ui--forms--email-target='input']")
    expect(component).to_not have_css("input[required]")
    expect(component).to have_css("[aria-live='polite'] p[class~='tw:hidden'][data-ui--forms--email-target='warning']",
      text: "That doesn't look like your real email address. Please enter an email address where you receive email")
    expect(component).to have_css("[aria-live='polite'] div button[class~='tw:hidden!'][data-ui--forms--email-target='override']",
      text: "Submit form anyway")
  end

  # Only the address is a button, and the controller is what fills it in
  it "wraps an empty correction button in the message that carries it" do
    expect(component).to have_css("p[data-ui--forms--email-target='suggestion']", text: "Did you mean ?")
    expect(component).to have_css("p[data-ui--forms--email-target='suggestion'] " \
      "button[data-ui--forms--email-target='correction']", text: "")
    # the "?" sits against the button, with no space formatting could have left behind
    expect(component.to_html).to include("</button>?")
  end

  # EmailDomain::RESERVED_REGEX is what the server checks, so this pins the syntax the
  # two share -- \A and \z would leave the controller with an unusable pattern.
  it "hands the controller the reserved-domain pattern as javascript reads it" do
    expect(component.css("[data-controller]").first["data-ui--forms--email-reserved-value"])
      .to eq '^(?:.+\.)?example\.(?:com|net|org)$|(?:^|\.)(?:test|example|invalid|localhost)$'
  end

  context "with required and html_options" do
    let(:options) { {attribute: :owner_email, required: true, html_options: {placeholder: "you@example.com"}} }

    it "passes them to the field" do
      expect(component).to have_css("input[type='email'][name='user[owner_email]'][required][placeholder='you@example.com']")
    end
  end

  context "with data in html_options" do
    let(:options) { {html_options: {data: {action: "input->something#else"}}} }

    it "keeps the target the controller needs" do
      expect(component).to have_css("input[data-ui--forms--email-target='input'][data-action='input->something#else']")
    end
  end
end
