# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::ComponentList::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike) }

  it "renders the full spec sheet toggle" do
    FactoryBot.create(:component, bike:)
    render_inline(described_class.new(bike: bike.reload))

    expect(page).to have_text("Full spec sheet")
    expect(page).to have_text("Show all")
  end

  it "injects the bike's wheel and drivetrain specs into the matching group cards" do
    FactoryBot.create(:cgroup, name: "Wheels", priority: 2)
    FactoryBot.create(:cgroup, name: "Drivetrain", priority: 3)
    wheel_size = FactoryBot.create(:wheel_size)
    bike.update(front_wheel_size: wheel_size, rear_wheel_size: wheel_size,
      front_gear_type: FactoryBot.create(:front_gear_type), rear_gear_type: FactoryBot.create(:rear_gear_type))

    render_inline(described_class.new(bike: bike.reload))

    expect(page).to have_text("Wheels")
    expect(page).to have_text("Wheel diameter")
    expect(page).to have_text("Drivetrain")
    expect(page).to have_text("Drivetrain rear")
  end
end
