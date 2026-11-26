# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CycleTypesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "#index" do
    it "renders a row drawing each cycle type by its slug, Bike Book's vehicle type, and hands the type_details their examples" do
      get "/admin/cycle_types"
      expect(response.status).to eq(200)
      document = Nokogiri::HTML(response.body)
      rows = document.css("tbody tr")
      expect(rows.count).to eq CycleType.all.count
      expect(rows.map { it["data-type"] }).to include("cargo-rear", "personal-mobility", "tricycle")
      expect(response.body).to include('data-admin--cycle-drawing-model-value="m/segway/2025/max-g3"')
      # the type_details' rows are the drawings' to add, with these examples
      examples = JSON.parse(document.at_css("[data-controller='admin--cycle-type-details']")["data-admin--cycle-type-details-examples-value"])
      expect(examples).to include("bike/step_through" => "m/aventon/2025/level-3-step-through", "tricycle/tadpole" => "m/reactive-adaptations/2025/hammerhead")
      # the rows with no catalog example, and the skateboard, wheelchair and unicycle, start collapsed at the bottom, each
      # opening both its drawings from its own URL param
      collapsed = rows.select { it["data-controller"] == "ui--collapse" }
      expect(collapsed.map { it["data-ui--collapse-param-value"] }).to match_array(%w[unicycle stroller wheelchair tall-bike penny-farthing cargo-trike-rear pedi-cab non-e-skateboard e-atv])
      expect(rows.to_a.last(collapsed.count)).to eq(collapsed)
      expect(collapsed.find { it["data-ui--collapse-param-value"] == "non-e-skateboard" }.css("[data-ui--collapse-target='content'] [data-controller='admin--cycle-drawing']").count).to eq 2
    end
  end
end
