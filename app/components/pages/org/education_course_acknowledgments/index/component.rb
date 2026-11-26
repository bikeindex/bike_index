# frozen_string_literal: true

module Pages
  module Org
    module EducationCourseAcknowledgments
      module Index
        # The education course acknowledgments, finished or not, on the organization's e-vehicles
        class Component < ApplicationComponent
          STATUSES = %w[acknowledged unfinished].freeze

          def initialize(pagy:, acknowledgments:, organization:, sort_state:, status:, period:, start_time:, end_time:, time_range:)
            @pagy = pagy
            @acknowledgments = acknowledgments
            @organization = organization
            @sort_state = sort_state
            @status = status
            @period = period
            @start_time = start_time
            @end_time = end_time
            @time_range = time_range
          end

          private

          def status_entries
            [nil, *STATUSES].map do |status|
              label = case status
              when "acknowledged" then translation(".acknowledged")
              when "unfinished" then translation(".unfinished")
              else translation(".all")
              end
              ComponentStructs::Shapes.entry(label, href: url_for(@sort_state.search_params.merge(search_status: status, page: nil)),
                active: @status == status)
            end
          end
        end
      end
    end
  end
end
