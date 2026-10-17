# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::TheftAlerts::PlanCounts::Component, type: :component do
  let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan) }
  let(:theft_alert_plan_other) { FactoryBot.create(:theft_alert_plan) }
  let!(:theft_alerts) do
    [
      FactoryBot.create(:theft_alert, theft_alert_plan:, reach: 10),
      FactoryBot.create(:theft_alert, theft_alert_plan:, reach: 5),
      FactoryBot.create(:theft_alert, theft_alert_plan: theft_alert_plan_other, reach: 7)
    ]
  end
  let(:component) do
    render_inline(described_class.new(theft_alert_plans: [theft_alert_plan, theft_alert_plan_other],
      theft_alerts: TheftAlert.all, recovered_stolen_records: StolenRecord.recovered.with_theft_alerts))
  end
  let(:cells) { ->(row) { row.css("td").map { |td| td.text.squish } } }

  it "renders a row per plan and sums them in the footer" do
    rows = component.css("tbody tr").map(&cells)
    expect(rows.map { |row| row[0..2] }).to eq([
      [theft_alert_plan.name + " $0.00", "2", "15"],
      [theft_alert_plan_other.name + " $0.00", "1", "7"]
    ])
    expect(cells.call(component.css("tfoot tr").first)[0..2]).to eq(["Total", "3", "22"])
  end
end
