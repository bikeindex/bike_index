# frozen_string_literal: true

module Pages
  module Admin
    module Graphs
      module YearCounts
        # Yearly stolen/recovered counts - everywhere, or within bounding_box, which leaves the
        # registration and user columns empty. The current year also gets an end-of-year projection
        class Component < ApplicationComponent
          FIRST_YEAR = 2013
          # SBR's import set created_at for these years, so they count date_stolen. After, created_at
          # is more reliable, and we're showing bikes registered/recorded - not stolen times
          DATE_STOLEN_YEARS = [2013, 2014].freeze
          REGISTRATION_LABELS = ["Stolen & non, in year", "Total Stolen & non by eoy", "Users in year"].freeze

          Row = Data.define(:year, :counts)

          def initialize(bounding_box: nil)
            @bounding_box = bounding_box
          end

          private

          def rows
            @rows ||= (FIRST_YEAR..Time.current.year).map do |year|
              Row.new(year:, counts: @bounding_box ? bounded_counts(year) : cached_everywhere_counts(year))
            end
          end

          def labels
            rows.first.counts.keys
          end

          def bikes
            Bike.with_user_hidden
          end

          def stolen_records
            @stolen_records ||= StolenRecord.unscoped.joins(:bike).merge(bikes)
              .then { |records| @bounding_box ? records.within_bounding_box(@bounding_box) : records }
          end

          # StolenRecord.recovered starts from unscoped, so chaining it drops the box. Every query on
          # this is a recovered_at condition, which already implies recovered
          def recovered_records
            @bounding_box ? stolen_records : StolenRecord.recovered
          end

          def cached_everywhere_counts(year)
            Rails.cache.fetch("admin_graphs_year_counts_#{year}", expires_in: 1.hour) do
              registered = with_projection(year, bikes, :created_at)
              stolen_counts(year, before_column: :date_stolen).merge(
                REGISTRATION_LABELS.zip([registered,
                  through_year(bikes.where(created_at: ...Date.new(year).all_year.last).count, registered),
                  with_projection(year, User.unscoped, :created_at)]).to_h
              )
            end
          end

          # The registrations and users a box would cover aren't counted, so their columns render empty
          def bounded_counts(year)
            stolen_counts(year, before_column: "stolen_records.created_at")
              .merge(REGISTRATION_LABELS.index_with(nil))
          end

          def stolen_counts(year, before_column:)
            date = Date.new(year)
            stolen = with_projection(year, stolen_records, DATE_STOLEN_YEARS.include?(year) ? :date_stolen : "stolen_records.created_at")
            recovered_in_year = with_projection(year, recovered_records, :recovered_at)
            {
              "Stolen in year" => stolen,
              "Total stolen by eoy" => through_year(stolen_records.where(before_column => ...date).count, stolen),
              "Recovered in year" => recovered_in_year,
              "Recovered by eoy" => through_year(recovered_records.where(recovered_at: ...date).count, recovered_in_year)
            }
          end

          # [count, projected end-of-year count] - only the current year is projected, without seasonality
          def with_projection(year, scope, column)
            count = scope.where(column => Date.new(year).all_year).count
            return [count, nil] unless year == Time.current.year

            [count, count + (BigDecimal(scope.where(column => past_year).count) / 365 * days_left).to_i]
          end

          def through_year(before, (count, projection))
            [before + count, projection && before + projection]
          end

          def past_year
            (Time.current - 1.year)..Time.current
          end

          def days_left
            Time.current.end_of_year.yday - Time.current.yday
          end
        end
      end
    end
  end
end
