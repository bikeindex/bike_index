# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Combobox::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {name: "manufacturer", options: combobox_options}.merge(extra) }
  let(:combobox_options) { %w[Trek Giant Surly] }
  let(:extra) { {} }

  it "renders an accessible combobox wired to the hw-combobox controller" do
    expect(component).to have_css("fieldset.hw-combobox[data-controller='hw-combobox']")
    expect(component).to have_css("input[role='combobox']")
    expect(component).to have_css("input[type='hidden'][name='manufacturer']", visible: :all)
    expect(component).to have_css("[role='option']", count: 3, visible: :all)
    expect(component).to have_css("[role='option'][data-value='Trek']", text: "Trek", visible: :all)
  end

  it "renders no label of its own, and ids the input with the name so a Group label can target it" do
    expect(component).to_not have_css("label", visible: :all, text: /\S/)
    expect(component).to have_css("input[role='combobox'][id='manufacturer']")
  end

  context "with hash options" do
    let(:combobox_options) { [{display: "Black", value: "1"}, {display: "Blue", value: "2"}] }

    it "renders the display text with the underlying value" do
      expect(component).to have_css("[role='option'][data-value='1']", text: "Black", visible: :all)
      expect(component).to have_css("[role='option'][data-value='2']", text: "Blue", visible: :all)
    end
  end

  context "with a preselected value" do
    let(:extra) { {value: "Surly"} }

    it "prefills the value" do
      expect(component).to have_css("[data-hw-combobox-prefilled-display-value='Surly']")
      expect(component).to have_css("input[type='hidden'][value='Surly']", visible: :all)
    end
  end

  context "with a form builder" do
    let(:component) do
      render_in_view_context do
        form_for Bike.new, url: "#", builder: BikeIndexFormBuilder do |f|
          render(UI::Forms::Combobox::Component.new(name: :manufacturer, form: f, options: %w[Trek Giant Surly]))
        end
      end
    end

    it "leaves the input id to the form builder, matching a Group label's for" do
      expect(component).to have_css("input[role='combobox'][id='bike_manufacturer']")
      expect(component).to have_css("input[type='hidden'][name='bike[manufacturer]']", visible: :all)
    end
  end

  context "with src for async loading" do
    let(:options) { {name: "manufacturer", src: "/manufacturers"} }

    it "renders an async endpoint instead of inline options" do
      html = component.to_html
      expect(html).to include("data-hw-combobox-async-src-value")
      expect(html).to include("/manufacturers")
      expect(component).not_to have_css("[role='option']", visible: :all)
    end
  end
end
