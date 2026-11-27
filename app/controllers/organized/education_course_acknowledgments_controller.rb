module Organized
  class EducationCourseAcknowledgmentsController < Organized::BaseController
    include Binxtils::SortableTable

    def index
      status = params[:search_status].presence_in(Pages::Org::EducationCourseAcknowledgments::Index::Component::STATUSES)
      pagy, acknowledgments = pagy(:countish, matching_acknowledgments(status)
        .preload({bike: :current_ownership}, education_course: :organization).reorder(sortable_order((sort_column == "created_at") ? Bike : EducationCourseAcknowledgment)),
        limit: permitted_per_page, page: permitted_page)

      render Pages::Org::EducationCourseAcknowledgments::Index::Component.new(pagy:, acknowledgments:,
        organization: current_organization, sort_state:, status:, period: @period, start_time: @start_time, end_time: @end_time,
        first_course: EducationCourse.first_for(current_organization))
    end

    private

    # created_at is the registration's, which an unfinished acknowledgment has as well
    def sortable_columns
      %w[created_at acknowledged_at owner_email].freeze
    end

    def matching_acknowledgments(status)
      acknowledgments = EducationCourseAcknowledgment.for_organization_bikes(current_organization)
        .joins(:bike).where(bikes: {created_at: @time_range})
      case status
      when "acknowledged" then acknowledgments.acknowledged
      when "unfinished" then acknowledgments.pending
      else acknowledgments
      end
    end
  end
end
