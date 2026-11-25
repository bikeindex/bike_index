# frozen_string_literal: true

module Pages
  module Admin
    module TheftAlerts
      module PlanCounts
        class Component < ApplicationComponent
          Row = Data.define(:name, :amount_cents_facebook, :alert_count, :fbook_reach, :fbook_cents, :revenue_cents, :recovered_count)

          SUMMED = %i[alert_count fbook_reach fbook_cents revenue_cents recovered_count].freeze

          def initialize(theft_alert_plans:, theft_alerts:, recovered_stolen_records:)
            @theft_alert_plans = theft_alert_plans
            @theft_alerts = theft_alerts
            @recovered_stolen_records = recovered_stolen_records
          end

          private

          def rows
            @rows ||= @theft_alert_plans.map do |theft_alert_plan|
              plan_theft_alerts = @theft_alerts.where(theft_alert_plan:)
              Row.new(
                name: theft_alert_plan.name,
                amount_cents_facebook: theft_alert_plan.amount_cents_facebook,
                alert_count: plan_theft_alerts.count,
                fbook_reach: plan_theft_alerts.sum(:reach),
                fbook_cents: plan_theft_alerts.sum(:amount_cents_facebook_spent),
                revenue_cents: plan_theft_alerts.paid_cents,
                recovered_count: @recovered_stolen_records.where(theft_alerts: {theft_alert_plan_id: theft_alert_plan.id}).count
              )
            end
          end

          def totals
            @totals ||= SUMMED.index_with { |key| rows.sum(&key) }
          end
        end
      end
    end
  end
end
