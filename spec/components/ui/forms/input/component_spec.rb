# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Input::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, html_options:)) }
  let(:attribute) { :name }
  let(:kind) { :text_field }
  let(:html_options) { {} }
  # As the browser reads it
  let(:pattern) { Regexp.new("\\A(?:#{component.css("input").first["pattern"]})\\z") }

  it "renders a text field, unwrapped" do
    expect(component).to have_css("input[type='text'][name='user[name]']")
    expect(component.to_html).to include("twinput")
    expect(component).to_not have_css("div")
    expect(component).to_not have_css("input[class~='tw:rounded-l-none']")
    expect(component).to_not have_css("input[title], [data-controller]")
  end

  context "when text_area" do
    let(:kind) { :text_area }

    it "renders a textarea" do
      expect(component).to have_css("textarea[name='user[name]']")
    end
  end

  context "when number_field" do
    let(:kind) { :number_field }

    it "renders a number input" do
      expect(component).to have_css("input[type='number']")
    end
  end

  context "when telephone_field" do
    let(:kind) { :telephone_field }

    it "renders a tel input, with the pattern the server checks and what it wants" do
      expect(component).to have_css("input[type='tel'][name='user[name]'][autocomplete='tel']")
      input = component.css("input").first
      expect(input["title"]).to eq "Enter a phone number with at least 7 digits, like 503 555 0123"
      expect(input["data-ui--forms--format-message-message-value"]).to eq input["title"]
      expect(input["data-controller"]).to eq "ui--forms--format-message"
      expect(["(718) 383-9999", "+44 20 7946 0958 x12"]).to all(match(pattern))
      expect("callmemaybe").to_not match(pattern)
    end
  end

  # type=url would refuse "example.com"
  context "when website_field" do
    let(:kind) { :website_field }

    it "renders a text input, with the pattern the server checks" do
      expect(component).to have_css("input[type='text'][inputmode='url'][autocomplete='url']")
      expect(["example.com", "https://www.example.co.uk/shop"]).to all(match(pattern))
      expect("http://not a website").to_not match(pattern)
    end

    context "with an autocomplete" do
      let(:html_options) { {autocomplete: "off"} }

      it "uses it" do
        expect(component).to have_css("input[autocomplete='off'][pattern]")
      end
    end
  end

  # An invalid pattern is ignored by the browser, rather than erroring
  it "escapes what the browser's v flag requires escaped in a class" do
    described_class::KIND_OPTIONS.each_value do |options|
      options[:pattern].scan(/\[\^?((?:\\.|[^\]\\])*)\]/).flatten.each do |character_class|
        expect(character_class.gsub(/\\./, "").gsub(/\w-\w/, "")).to_not match(%r{[()\[\]{}/\-|]})
      end
    end
  end

  context "when postal_code_field" do
    let(:kind) { :postal_code_field }

    it "renders a text input, with the pattern the server checks" do
      expect(component).to have_css("input[type='text'][autocomplete='postal-code']")
      expect(["T6E 2A4", "t6e2a4", " K1A 0B1 ", "97201", "12345-6789", "SW1A 1AA", "D02 X285", "1012 AB",
        "01310-100", "C1420ABC", "100-0001", "LV-1050", "SE-123 45", "12345-67890", "AD100", "100", "CAYMAN KY1-1100"])
        .to all(match(pattern))
      expect(["1", "12", "T6E 2A4!", "#97201"].grep(pattern)).to be_empty
    end
  end

  # An email field is UI::Forms::Email, so every one of them checks for a typo, and a
  # select is UI::Forms::Select — neither may quietly render as a text field instead
  context "when the kind isn't one of KINDS" do
    it "raises" do
      [:email_field, :select, :password_field, nil].each do |unknown_kind|
        expect { described_class.new(form_builder:, attribute:, kind: unknown_kind) }
          .to raise_error(ArgumentError, /unknown kind/)
      end
    end
  end

  context "with html_options" do
    let(:html_options) { {placeholder: "Enter name"} }

    it "passes options through" do
      expect(component).to have_css("input[placeholder='Enter name']")
    end
  end

  context "with a class in html_options" do
    let(:html_options) { {class: "tw:font-mono"} }

    it "appends to twinput rather than replacing it" do
      expect(component).to have_css("input.twinput.tw\\:font-mono")
    end
  end

  context "with a prefix" do
    let(:component) { render_inline(described_class.new(form_builder:, attribute:, prefix: "@", html_options:)) }

    it "renders it beside the field, squaring the field's left corners" do
      expect(component).to have_css("div[class~='tw:flex'] > span", text: "@")
      expect(component).to have_css("div[class~='tw:flex'] > input.twinput[class~='tw:rounded-l-none']")
    end
  end

  context "when required" do
    let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, required: true)) }

    it "renders the required attribute" do
      expect(component).to have_css("input[type='text'][required]")
    end
  end
end
