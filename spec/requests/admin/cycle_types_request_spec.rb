# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CycleTypesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "#index" do
    it "renders a row drawing each cycle type by its BikeBook vehicle type, and hands the type_details their examples" do
      get "/admin/cycle_types"
      expect(response.status).to eq(200)
      document = Nokogiri::HTML(response.body)
      rows = document.css("tbody tr")
      expect(rows.count).to eq CycleType.all.count
      expect(rows.map { it["data-type"] }).to include("cargo_bike_rear", "epamd", "tricycle")
      expect(response.body).to include('data-admin--cycle-drawing-model-value="m/segway/2025/max_g3"')
      # the type_details' rows are the drawings' to add, with these examples
      examples = JSON.parse(document.at_css("[data-controller='admin--cycle-type-details']")["data-admin--cycle-type-details-examples-value"])
      expect(examples).to include("bike/step_through" => "m/aventon/2025/level_3_step_through", "tricycle/tadpole" => "m/reactive_adaptations/2025/hammerhead")
      # the rows with no catalog example, and skateboard, wheelchair and unicycle, start collapsed at the bottom, each
      # opening both its drawings from its own URL param
      collapsed = rows.select { it["data-controller"] == "ui--collapse" }
      expect(collapsed.map { it["data-ui--collapse-param-value"] }).to match_array(%w[unicycle stroller wheelchair tall_bike penny_farthing cargo_tricycle_rear pedi_cab skateboard])
      expect(rows.to_a.last(collapsed.count)).to eq(collapsed)
      expect(collapsed.find { it["data-ui--collapse-param-value"] == "skateboard" }.css("[data-ui--collapse-target='content'] [data-controller='admin--cycle-drawing']").count).to eq 2
    end
  end
end
