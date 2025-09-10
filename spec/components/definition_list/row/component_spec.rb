# frozen_string_literal: true

require "rails_helper"

RSpec.describe DefinitionList::Row::Component, type: :component do
  let(:options) { {label:, value:} }
  let(:label) { "some thing" }
  let(:value) { "Description of the thing" }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(described_class.new(**options).render?).to be_truthy
    expect(component).to be_present
    expect(component).to have_text label
  end

  context "no value" do
    let(:options) { {label:} }

    it "is render? false" do
      expect(described_class.new(**options).render?).to be_falsey
      expect(component).to_not have_text label
    end

    context "render_with_no_value: true" do
      let(:options) { {label:, render_with_no_value: true} }
      it "is render? true" do
        expect(described_class.new(**options).render?).to be_truthy
        expect(component).to be_present
        expect(component).to have_text label
        expect(component).to have_text "none" # no_value_content
      end
    end
  end

  context "blank value" do
    let(:value) { "   \n" }

    it "is render? false" do
      expect(described_class.new(**options).render?).to be_falsey
      expect(component).to_not have_text label
    end

    context "render_with_no_value: true" do
      let(:options) { {label:, value:, render_with_no_value: true} }
      it "is render? true" do
        expect(described_class.new(**options).render?).to be_truthy
        expect(component).to be_present
        expect(component).to have_text label
      end
    end
  end
end
