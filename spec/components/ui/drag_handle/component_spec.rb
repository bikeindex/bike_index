# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::DragHandle::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {controller: "sortable"} }

  it "renders a draggable grip targeting the controller's handle" do
    expect(component).to have_css("span[draggable='true'][data-sortable-target='handle']")
    expect(component.to_html).to include("tw:cursor-grab")
  end

  context "with a hyphenated controller and extra classes" do
    let(:options) { {controller: "bullet-editors", html_class: "tw:pt-2"} }

    it "dasherizes the target key and appends the classes" do
      expect(component).to have_css("span[data-bullet-editors-target='handle'].tw\\:pt-2", visible: :all)
    end
  end
end
