# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Checkbox::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {name: :subscribe, label: "Email me updates"} }

  it "renders a label-wrapped checkbox" do
    expect(component).to have_css("label.twlabel input[type='checkbox'][name='subscribe']")
    expect(component).to have_css("label", text: "Email me updates")
    expect(component).to_not have_css("input[checked]")
    expect(component).to_not have_css("input[required]")
  end

  context "when required" do
    let(:options) { {name: :subscribe, label: "Email me updates", required: true} }

    it "renders the checkbox required" do
      expect(component).to have_css("input[type='checkbox'][required]")
    end
  end

  context "when checked with custom value and data" do
    let(:options) do
      {name: :serial_missing, label: "Missing", checked: true, value: true,
       class_name: "tw:mt-2", html_options: {data: {action: "change->serial#toggle"}}}
    end

    it "renders checked with the passed value and data" do
      expect(component).to have_css("input[type='checkbox'][value='true'][checked]", visible: :all)
      expect(component).to have_css("label.tw\\:mt-2")
      expect(component).to have_css("input[data-action='change->serial#toggle']", visible: :all)
    end
  end

  context "with html_options" do
    let(:options) do
      {name: :search_all, label: "Search all", html_options: {form: "Search_Form", disabled: true, class: "tw:accent-blue-600"}}
    end

    it "puts them on the input, joining its own classes" do
      input = component.css("input[type='checkbox']").first
      expect(input["form"]).to eq "Search_Form"
      expect(input["disabled"]).to be_present
      expect(input["class"].split).to include("tw:accent-blue-600", "tw:shrink-0")
    end
  end

  context "with a form builder" do
    let(:form_builder) do
      BikeIndexFormBuilder.new(:user, User.new, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
    end
    let(:options) { {form_builder:, attribute: :terms_of_service, label: "I agree"} }

    it "renders a model-scoped checkbox with the hidden companion input" do
      expect(component).to have_css("label.twlabel input[type='checkbox'][name='user[terms_of_service]']", visible: :all)
      expect(component).to have_css("input[type='hidden'][name='user[terms_of_service]'][value='0']", visible: :all)
      expect(component).to have_css("label", text: "I agree")
    end
  end

  context "with neither name nor form builder" do
    let(:options) { {label: "Orphan"} }

    it "raises" do
      expect { component }.to raise_error(ArgumentError)
    end
  end
end
