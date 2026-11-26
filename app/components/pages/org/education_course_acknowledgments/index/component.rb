# frozen_string_literal: true

module Pages
  module Org
    module EducationCourseAcknowledgments
      module Index
        # The education course acknowledgments, finished or not, on the organization's e-vehicles
        class Component < ApplicationComponent
          STATUSES = %w[acknowledged unfinished].freeze

          def initialize(pagy:, acknowledgments:, organization:, sort_state:, status:, period:, start_time:, end_time:)
            @pagy = pagy
            @acknowledgments = acknowledgments
            @organization = organization
            @sort_state = sort_state
            @status = status
            @period = period
            @start_time = start_time
            @end_time = end_time
          end

          private

          def status_entries
            {nil => translation(".all"), "acknowledged" => translation(".acknowledged"),
             "unfinished" => translation(".unfinished")}.map do |status, label|
              ComponentStructs::Shapes.entry(label, href: url_for(@sort_state.search_params.merge(search_status: status)),
                active: @status == status)
            end
          end
        end
      end
    end
  end
end
