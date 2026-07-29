# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Email::Component, type: :component do
  # No object, so the field renders whatever attribute it's given
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, nil, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, **options)) }
  let(:options) { {} }

  it "renders an email field with the suggestion hidden" do
    expect(component).to have_css("input.twinput[type='email'][name='user[email]'][data-ui--forms--email-target='input']")
    expect(component).to_not have_css("input[required]")
    expect(component).to have_css("[data-ui--forms--email-message-value='Did you mean %{email}?']")
    expect(component).to have_css("[aria-live='polite'] button[class~='tw:hidden!'][data-ui--forms--email-target='suggestion']")
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
