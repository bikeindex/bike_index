# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Input::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) do
    render_inline(described_class.new(form_builder:, attribute:, kind:, choices:, select_options:, html_options:))
  end
  let(:attribute) { :name }
  let(:kind) { :text_field }
  let(:choices) { nil }
  let(:select_options) { {} }
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

  context "when email_field" do
    let(:kind) { :email_field }
    let(:attribute) { :email }

    it "renders an email input" do
      expect(component).to have_css("input[type='email'][name='user[email]']")
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

  context "when select" do
    let(:kind) { :select }
    let(:choices) { [["Red", "1"], ["Blue", "2"]] }
    let(:select_options) { {selected: "2", include_blank: "Pick one"} }

    it "renders a select with twinput, options, and the selected value" do
      expect(component).to have_css("select.twinput[name='user[name]']")
      expect(component).to have_css("option[value='2'][selected]", text: "Blue")
      expect(component).to have_css("option[value='']", text: "Pick one")
    end
  end

  context "when invalid kind" do
    let(:kind) { :password_field }

    it "falls back to text_field" do
      expect(component).to have_css("input[type='text']")
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

  context "when required" do
    let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, required: true)) }

    it "renders the required attribute" do
      expect(component).to have_css("input[type='text'][required]")
    end
  end
end
