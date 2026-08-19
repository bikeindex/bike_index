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

  it "renders a text field" do
    expect(component).to have_css("input[type='text'][name='user[name]']")
    expect(component.to_html).to include("twinput")
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

    it "renders a tel input" do
      expect(component).to have_css("input[type='tel'][name='user[name]']")
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

  # The prefix sits against the field's left edge, rather than on a line of its own
  context "with a prefix" do
    let(:component) { render_inline(described_class.new(form_builder:, attribute:, prefix: "@", html_options:)) }

    it "renders it beside the field, squaring the field's left corners" do
      expect(component).to have_css("div[class~='tw:flex'] > span", text: "@")
      expect(component).to have_css("div[class~='tw:flex'] > input.twinput[class~='tw:rounded-l-none']")
    end
  end

  it "renders no wrapper without a prefix" do
    expect(component).to have_css("input.twinput")
    expect(component).to_not have_css("div")
    expect(component).to_not have_css("input[class~='tw:rounded-l-none']")
  end

  context "when required" do
    let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, required: true)) }

    it "renders the required attribute" do
      expect(component).to have_css("input[type='text'][required]")
    end
  end
end
