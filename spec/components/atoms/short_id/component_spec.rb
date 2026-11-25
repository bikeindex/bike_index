# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::ShortId::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {short_id: "r/21J-HW"} }

  it "renders the short_id in a monospace code block with a copy button" do
    expect(component).to have_css("code", text: "r/21J-HW")
    expect(component.to_html).to include("tw:font-mono")
    expect(component).to have_css("button[title='Copy ID'][data-ui--copy-button-text-value='r/21J-HW']")
  end

  context "with a record" do
    let(:record) { Bike.new(id: 36) }
    let(:options) { {record:} }

    it "renders the record's short_id" do
      expect(component).to have_css("code", text: record.short_id)
    end
  end

  context "with a blank short_id" do
    let(:options) { {short_id: nil} }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
