# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Group::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, label_text:, label_suffix:)) }
  let(:attribute) { :name }
  let(:kind) { :text_field }
  let(:label_text) { nil }
  let(:label_suffix) { nil }

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
    let(:label_text) { "Model" }
    let(:label_suffix) { "<em>opt</em>".html_safe }

    it "renders the suffix inside the label, above the field" do
      expect(component).to have_css("label", text: "Model")
      expect(component).to have_css("label em", text: "opt")
      expect(component).to have_css("input.twinput.tw\\:mt-1")
    end
  end

  context "when select" do
    let(:component) do
      render_inline(described_class.new(form_builder:, attribute:, kind: :select,
        choices: [["Red", "1"], ["Blue", "2"]], select_options: {selected: "2"}))
    end

    it "forwards the choices through to UI::Forms::Input" do
      expect(component).to have_css("label[for='user_name']", text: "Name")
      expect(component).to have_css("select.twinput[name='user[name]']")
      expect(component).to have_css("option[value='2'][selected]", text: "Blue")
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
