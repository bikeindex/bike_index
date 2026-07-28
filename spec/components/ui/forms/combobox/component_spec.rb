# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Combobox::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {name: "cycle_type", options: combobox_options}.merge(extra) }
  let(:combobox_options) { %w[Bike Tandem Unicycle] }
  let(:extra) { {} }

  it "renders an accessible combobox wired to the hw-combobox controller" do
    expect(component).to have_css("fieldset.hw-combobox[data-controller='hw-combobox']")
    expect(component).to have_css("input[role='combobox']")
    expect(component).to have_css("input[type='hidden'][name='cycle_type']", visible: :all)
    expect(component).to have_css("[role='option']", count: 3, visible: :all)
    expect(component).to have_css("[role='option'][data-value='Tandem']", text: "Tandem", visible: :all)
  end

  it "renders no label of its own, and ids the input with the name so a Group label can target it" do
    expect(component).to_not have_css("label.hw-combobox__label", visible: :all, text: /\S/)
    expect(component).to have_css("input[role='combobox'][id='cycle_type']")
  end

  it "labels the mobile dialog's input, which a Group label can't reach" do
    expect(component).to have_css("label.hw-combobox__dialog__label[for='cycle_type-hw-dialog-combobox']",
      text: "Cycle type", visible: :all)
  end

  context "with a dialog_label" do
    let(:extra) { {dialog_label: "Kind of cycle"} }

    it "overrides the humanized name" do
      expect(component).to have_css("label.hw-combobox__dialog__label", text: "Kind of cycle", visible: :all)
    end
  end

  context "with rich_display" do
    let(:extra) { {rich_display: true} }

    it "wraps the combobox with the overlay the display controller paints on" do
      expect(component).to have_css("div.tw\\:relative[data-controller='ui--forms--combobox-display'] fieldset.hw-combobox")
      expect(component).to have_css("[data-ui--forms--combobox-display-target='overlay'].tw\\:hidden", visible: :all)
    end

    context "with a class string" do
      let(:extra) { {rich_display: "tw:flex-1"} }

      it "puts it on the wrapper" do
        expect(component).to have_css("div.tw\\:relative.tw\\:flex-1[data-controller='ui--forms--combobox-display']")
      end
    end
  end

  context "with hash options" do
    let(:combobox_options) { [{display: "[622] 700c", value: "1"}, {display: "[559] 26in", value: "2"}] }

    it "renders the display text with the underlying value" do
      expect(component).to have_css("[role='option'][data-value='1']", text: "[622] 700c", visible: :all)
      expect(component).to have_css("[role='option'][data-value='2']", text: "[559] 26in", visible: :all)
    end
  end

  context "with a preselected value" do
    let(:extra) { {value: "Unicycle"} }

    it "prefills the value" do
      expect(component).to have_css("[data-hw-combobox-prefilled-display-value='Unicycle']")
      expect(component).to have_css("input[type='hidden'][value='Unicycle']", visible: :all)
    end
  end

  context "with a form builder" do
    let(:component) do
      render_in_view_context do
        form_for Bike.new, url: "#", builder: BikeIndexFormBuilder do |f|
          render(UI::Forms::Combobox::Component.new(name: :primary_activity_id, form: f, options: %w[Road Gravel]))
        end
      end
    end

    it "leaves the input id to the form builder, matching a Group label's for" do
      expect(component).to have_css("input[role='combobox'][id='bike_primary_activity_id']")
      expect(component).to have_css("input[type='hidden'][name='bike[primary_activity_id]']", visible: :all)
    end
  end

  context "with src for async loading" do
    let(:options) { {name: "primary_activity", src: "/primary_activities"} }

    it "renders an async endpoint instead of inline options" do
      html = component.to_html
      expect(html).to include("data-hw-combobox-async-src-value")
      expect(html).to include("/primary_activities")
      expect(component).not_to have_css("[role='option']", visible: :all)
    end
  end
end
