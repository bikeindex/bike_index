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
    expect(component).to_not have_css("input[aria-describedby]")
  end

  # A field whose required-ness is decided in the browser carries both markers, since a
  # controller can flip their hidden state but can't rebuild the label
  context "required_toggleable" do
    let(:component) do
      render_inline(described_class.new(form_builder:, attribute:, required:, required_toggleable: true))
    end

    it "renders both markers, hiding the required one" do
      expect(component).to have_css("[data-required-marker][hidden]", text: "*", visible: :all)
      expect(component).to have_css("[data-optional-marker]", text: "optional")
      expect(component).to_not have_css("[data-optional-marker][hidden]", visible: :all)
      expect(component).to_not have_css("input[required]")
    end

    context "required" do
      let(:required) { true }

      it "hides the optional one instead" do
        expect(component).to have_css("[data-required-marker]", text: "*")
        expect(component).to_not have_css("[data-required-marker][hidden]", visible: :all)
        expect(component).to have_css("[data-optional-marker][hidden]", text: "optional", visible: :all)
        expect(component).to have_css("input[required]")
      end
    end
  end

  it "renders one unmarked suffix without it" do
    expect(component).to_not have_css("[data-required-marker], [data-optional-marker]", visible: :all)
    expect(component).to have_css("label", text: "optional")
  end

  context "with custom label" do
    let(:label_text) { "Display Name" }

    it "uses custom label text" do
      expect(component).to have_css("label", text: "Display Name")
    end
  end

  # There's no email kind -- UI::Forms::Email renders one, so it arrives in a block
  context "when a content block wraps an email field" do
    let(:component) do
      render_in_view_context do
        form_for User.new, url: "#", method: :patch, builder: BikeIndexFormBuilder do |f|
          render(UI::Forms::Group::Component.new(form_builder: f, attribute: :email, required: true)) do
            render(UI::Forms::Email::Component.new(form_builder: f, required: true))
          end
        end
      end
    end

    it "labels the email field rendered in the block" do
      expect(component).to have_css("label[for='user_email']", text: "Email")
      expect(component).to have_css("[data-controller='ui--forms--email'] input.twinput[type='email'][name='user[email]'][required]")
    end
  end

  context "when text_area" do
    let(:kind) { :text_area }

    it "renders textarea with label" do
      expect(component).to have_css("label", text: "Name")
      expect(component).to have_css("textarea")
    end
  end

  # Raising even with a block, where the kind goes unused, keeps a dead one from
  # sitting there until the block is removed and it silently becomes a text field
  context "when the kind isn't one UI::Forms::Input renders" do
    it "raises" do
      [:email_field, :select, nil].each do |unknown_kind|
        expect { described_class.new(form_builder:, attribute:, kind: unknown_kind) }
          .to raise_error(ArgumentError, /unknown kind/)
      end
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

  describe "helper_text" do
    let(:component) do
      render_inline(described_class.new(form_builder:, attribute:)) do |group|
        group.with_helper_text { "email, username or id" }
      end
    end

    # The block sets a slot and renders no field, so UI::Forms::Input still has to run
    it "renders under the input, which describes itself with it" do
      expect(component).to have_css("input.twinput[aria-describedby='user_name_helper']")
      expect(component).to have_css("p#user_name_helper", text: "email, username or id")
    end

    # Group can't reach the field a block renders, so the block describes it instead
    context "with a content block" do
      let(:component) do
        render_in_view_context do
          render(UI::Forms::Group::Component.new(attribute: :cycle_type)) do |group|
            group.with_helper_text { "pick the closest match" }
            render(UI::Forms::Combobox::Component.new(name: :cycle_type, options: %w[Bike Tandem],
              "aria-describedby": group.helper_text_id))
          end
        end
      end

      it "renders the helper text with the id the block described its field by" do
        expect(component).to have_css("p#cycle_type_helper", text: "pick the closest match")
        expect(component).to have_css("input[role='combobox'][aria-describedby='cycle_type_helper']")
      end
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
    let(:rule) { Rails.root.join("app/assets/tailwind/bike_index_components.css").read[/^\s*\.twlabel \{(.*?)\}/m, 1] }

    it "is block, with the gap to its field" do
      expect(rule).to include("tw:block")
      expect(rule).to include("tw:mb-1")
    end
  end
end
