# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Group::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, label_text:)) }
  let(:attribute) { :name }
  let(:kind) { :text_field }
  let(:label_text) { nil }

  it "renders label and input" do
    expect(component).to have_css("label[for='user_name']", text: "Name")
    expect(component).to have_css("input[type='text'][name='user[name]']")
  end

  context "with custom label" do
    let(:label_text) { "Display Name" }

    it "uses custom label text" do
      expect(component).to have_css("label", text: "Display Name")
    end
  end

  context "when email_field" do
    let(:attribute) { :email }
    let(:kind) { :email_field }

    it "renders email input with label" do
      expect(component).to have_css("label", text: "Email")
      expect(component).to have_css("input[type='email']")
    end
  end

  context "when text_area" do
    let(:kind) { :text_area }

    it "renders textarea with label" do
      expect(component).to have_css("label", text: "Name")
      expect(component).to have_css("textarea")
    end
  end

  context "with label_suffix" do
    let(:component) do
      render_inline(described_class.new(form_builder:, attribute:, kind:, label_text: "Model",
        label_suffix: "<em>opt</em>".html_safe))
    end

    it "renders the suffix inside the label, above the field" do
      expect(component).to have_css("label", text: "Model")
      expect(component).to have_css("label em", text: "opt")
      expect(component).to have_css("input.twinput.tw\\:mt-1")
    end
  end

  context "by default" do
    it "appends an optional badge for a non-required field" do
      expect(component).to have_css("label", text: "optional")
      expect(component).to_not have_css("label span", text: "*")
    end

    context "when required" do
      let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, required: true)) }

      it "marks the input required and appends an asterisk instead of the badge" do
        expect(component).to have_css("input[required]")
        expect(component).to have_css("label span", text: "*")
        expect(component).to_not have_text("optional")
      end
    end

    context "when label_suffix is nil" do
      let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, label_suffix: nil)) }

      it "omits the suffix" do
        expect(component).to_not have_text("optional")
        expect(component).to_not have_css("label span", text: "*")
      end
    end
  end

  context "when content_block" do
    let(:kind) { :content_block }
    let(:component) do
      render_inline(described_class.new(form_builder:, attribute:, kind:, label_text:)) do
        "<my-field></my-field>".html_safe
      end
    end

    it "renders the label and content block, skipping UI::Forms::Input" do
      expect(component).to have_css("label[for='user_name']", text: "Name")
      expect(component).to have_css("my-field")
      expect(component).to_not have_css("input")
      expect(component).to_not have_css("textarea")
    end
  end
end
