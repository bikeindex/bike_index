# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Group::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, label_text:, required:)) }
  let(:attribute) { :name }
  let(:kind) { :text_field }
  let(:label_text) { nil }
  let(:required) { false }

  it "renders label and input" do
    expect(component).to have_css("label[for='user_name']", text: "Name")
    expect(component).to have_css("input[type='text'][name='user[name]']")
    # .twlabel carries the gap to the field, so neither side spaces itself
    expect(component).to have_css("label.twlabel")
    expect(component).to_not have_css("[class*='tw:mt-1'], [class*='tw:mb-1']")
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

  it "appends an optional badge for a non-required field" do
    expect(component).to have_css("label", text: "optional")
    expect(component).to_not have_css("label span", text: "*")
    expect(component).to have_css("input.twinput")
  end

  context "when required" do
    let(:required) { true }

    it "marks the input required and appends an asterisk instead of the badge" do
      expect(component).to have_css("input[required]")
      expect(component).to have_css("label span", text: "*")
      expect(component).to_not have_text("optional")
    end
  end

  context "when a content block wraps a select" do
    let(:component) do
      render_in_view_context do
        form_for User.new, url: "#", method: :patch, builder: BikeIndexFormBuilder do |f|
          render(UI::Forms::Group::Component.new(form_builder: f, attribute: :name)) do
            render(UI::Forms::Select::Component.new(form_builder: f, attribute: :name,
              option_tags: [["Red", "1"], ["Blue", "2"]], options: {selected: "2"}))
          end
        end
      end
    end

    # What the select itself renders is UI::Forms::Select's spec; this is about
    # the label pointing at a field the Group didn't render
    it "labels the select rendered in the block" do
      expect(component).to have_css("label[for='user_name']", text: "Name")
      expect(component).to have_css("select.twinput[name='user[name]']")
    end
  end

  context "when a content block wraps a combobox, without a form_builder" do
    let(:component) do
      render_in_view_context do
        render(UI::Forms::Group::Component.new(attribute: :cycle_type)) do
          render(UI::Forms::Combobox::Component.new(name: :cycle_type, options: %w[Bike Tandem]))
        end
      end
    end

    it "labels the combobox by its name" do
      expect(component).to have_css("label[for='cycle_type']", text: "Cycle type")
      expect(component).to have_css("input[role='combobox'][id='cycle_type']")
    end
  end

  context "when given a content block" do
    let(:component) do
      render_inline(described_class.new(form_builder:, attribute:, label_text:)) do
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

  it "raises without a form_builder or a content block, since there'd be no field to render" do
    expect { render_inline(described_class.new(attribute: :name)) }
      .to raise_error(ArgumentError, /form_builder/)
  end

  # The gap to the field lives on .twlabel rather than on either side, so it
  # applies to a content block too -- Group can't reach the field there. It also
  # has to beat Bootstrap's `.container label`, which is inline-block with a
  # .5rem margin and only applies inside a container.
  describe ".twlabel" do
    let(:rule) { Rails.root.join("app/assets/tailwind/application.css").read[/^\s*\.twlabel \{(.*?)\}/m, 1] }

    it "is block, with the gap to its field" do
      expect(rule).to include("tw:block")
      expect(rule).to include("tw:mb-1")
    end
  end
end
