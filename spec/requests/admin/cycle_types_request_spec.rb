# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CycleTypesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "#index" do
    it "renders a drawing of each cycle type by its Bikebook vehicle type, and of the type_details drawn their own way" do
      get "/admin/cycle_types"
      expect(response.status).to eq(200)
      expect(response.body).to include('data-admin--cycle-drawing-type-value="cargo_bike_rear"')
      expect(response.body).to include('data-admin--cycle-drawing-type-value="epamd"')
      expect(response.body).to include('data-admin--cycle-drawing-type-detail-value="tadpole"')
      expect(response.body).to include('data-admin--cycle-drawing-model-value="m/segway/2025/max_g3"')
      expect(response.body).to include('data-admin--cycle-drawing-model-value="m/cycrown/2026/run_mini"')
      # the rows with no catalog example, and skateboard, wheelchair and unicycle, start collapsed at the bottom, each
      # opening both its drawings from its own URL param
      rows = Nokogiri::HTML(response.body).css("tbody tr")
      collapsed = rows.select { it["data-controller"] == "ui--collapse" }
      expect(collapsed.map { it["data-ui--collapse-param-value"] }).to match_array(%w[unicycle stroller wheelchair tall_bike penny_farthing cargo_tricycle_rear pedi_cab skateboard])
      expect(rows.to_a.last(collapsed.count)).to eq(collapsed)
      expect(collapsed.find { it["data-ui--collapse-param-value"] == "skateboard" }.css("[data-ui--collapse-target='content'] [data-controller='admin--cycle-drawing']").count).to eq 2
      # a row per cycle type and type_detail, each drawn typical and most with a catalog example
      expect(response.body.scan('data-admin--cycle-drawing-type-value="').count).to eq(CycleType.all.count + 3 + Pages::Admin::CycleTypeDrawings::Component::EXAMPLE_MODELS.count)
    end
  end
end
