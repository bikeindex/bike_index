# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Checkbox::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {name: :subscribe, label: "Email me updates"} }

  it "renders a label-wrapped checkbox" do
    expect(component).to have_css("label.twlabel input[type='checkbox'][name='subscribe']")
    expect(component).to have_css("label", text: "Email me updates")
    expect(component).to_not have_css("input[checked]")
  end

  context "when checked with custom value and data" do
    let(:options) do
      {name: :serial_missing, label: "Missing", checked: true, value: true,
       class_name: "tw:mt-2", input_data: {action: "change->serial#toggle"}}
    end

    it "renders checked with the passed value and data" do
      expect(component).to have_css("input[type='checkbox'][value='true'][checked]", visible: :all)
      expect(component).to have_css("label.tw\\:mt-2")
      expect(component).to have_css("input[data-action='change->serial#toggle']", visible: :all)
    end
  end
end
