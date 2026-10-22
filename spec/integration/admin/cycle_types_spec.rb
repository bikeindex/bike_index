# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin cycle types", :js, type: :system do
  let(:user) { FactoryBot.create(:superuser) }

  before do
    # the fixture catalog's models, and one it doesn't have
    stub_const("Pages::Admin::CycleTypeDrawings::Component::EXAMPLE_MODELS", {
      "bike" => "m/aventon/2026/level_4_rec",
      "bike/step_through" => "m/aventon/2026/level_4_rec_step_through",
      "tricycle" => "m/sun/2022/miami_sun_traditional_24_step_thru"
    })
    serve_bikebook_catalog
    Organization.example # Logging in lands on the admin dashboard, which reads it from the replica
    sign_in(user)
  end

  def row(text) = find("tbody tr", text:)

  it "follows each type with its type_details' rows, drawing them from the catalog" do
    visit admin_cycle_types_path

    # each type_detail the drawings draw their own way, in a row of its own after its type's
    headers = all("tbody tr th", minimum: CycleType.all.count + 3).map { it.text.squish }
    bike = headers.index { it.start_with?("Bike bike") }
    expect(headers[bike + 1, 2]).to eq ["Bike bike type detail: step_through", "Bike bike type detail: bench_seat"]
    expect(headers[headers.index { it.start_with?("Tricycle tricycle") } + 1]).to eq "Tricycle tricycle type detail: tadpole"

    # typical, and its example model from the catalog, in the size BikeBook first shows it in
    within(row("type detail: step_through")) do
      expect(page).to have_css("svg[role='img']", count: 2, wait: 10)
      expect(page).to have_link(href: /vehicle_models=m%2Faventon%2F2026%2Flevel_4_rec_step_through&view=geometry/)
    end
    within(row("type detail: bench_seat")) { expect(page).to have_text("No catalog models") }
    within(row("type detail: tadpole")) do
      expect(page).to have_css("svg[role='img']", count: 1)
      expect(page).to have_text("No catalog models")
    end
    expect(page).to have_text("m/sun/2022/miami_sun_traditional_24_step_thru isn't in the published catalog yet")

    within(row("type detail: step_through")) do
      typical = first("[data-controller='admin--cycle-drawing']")
      within(typical) do
        expect(page).to have_button("Reset", disabled: true)
        fill_in "Stack", with: "700"
        expect(page).to have_field("Stack", with: "700")
        click_button "Reset"
        expect(page).to have_field("Stack", with: "570")
        expect(page).to have_button("Reset", disabled: true)

        # a tire's width is a figure like the others, drawn as listed once it's set
        expect(page).to have_css("svg [data-figure='tire_width_rear'][stroke='#9ca3af']")
        fill_in "Rear tire width", with: "80"
        expect(page).to have_css("svg [data-figure='tire_width_rear'][stroke='#715eb2']")
        click_button "Reset"

        # the legend letter, named for its figure, which a typical figure stays gray for
        find("button[aria-label='Highlight Stack']").click
        expect(page).to have_css("button[aria-label='Highlight Stack'][aria-pressed='true']")
        expect(page).to have_css("svg [data-figure='stack'][stroke='#9ca3af'][stroke-width='2.5']")
      end
    end
  end
end
