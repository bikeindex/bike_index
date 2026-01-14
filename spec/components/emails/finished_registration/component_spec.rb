# frozen_string_literal: true

require "rails_helper"

RSpec.describe Emails::FinishedRegistration::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {ownership:} }
  let(:ownership) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end

