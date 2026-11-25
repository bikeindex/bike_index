# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::RegistrationDates::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }
  let(:bike) { FactoryBot.create(:bike, updated_by_user_at: Time.current - 2.days) }

  it "renders both dates, with the labels and their abbreviations' tooltips" do
    expect(component).to have_css("span.localizeTime", count: 2)
    expect(component).to have_css("strong", text: "Registered")
    expect(component).to have_css("strong", text: "Updated")
    expect(component).to have_css("button[aria-label='Registered at']", text: "R")
    expect(component).to have_css("button[aria-label='Updated at']", text: "U")
  end
end
