module Organized
  class EducationCourseAcknowledgmentsController < Organized::BaseController
    include Binxtils::SortableTable

    before_action :ensure_access_to_education_courses!

    def index
      status = Pages::Org::EducationCourseAcknowledgments::Index::Component::STATUSES.find { it == params[:search_status] }
      pagy, acknowledgments = pagy(:countish, matching_acknowledgments(status)
        .preload(:bike, education_course: :organization).reorder(sort_order),
        limit: permitted_per_page, page: permitted_page)

      render Pages::Org::EducationCourseAcknowledgments::Index::Component.new(pagy:, acknowledgments:,
        organization: current_organization, sort_state:, status:, period: @period, start_time: @start_time,
        end_time: @end_time, time_range: @time_range)
    end

    private

    # created_at is the registration's, which an unfinished acknowledgment has as well
    def sortable_columns
      %w[created_at acknowledged_at owner_email].freeze
    end

    def sort_order
      (sort_column == "created_at") ? sortable_order("bikes.created_at") : sortable_order(EducationCourseAcknowledgment)
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

    def ensure_access_to_education_courses!
      return true if current_organization.enabled?("education_courses") || current_user.superuser?

      raise_do_not_have_access!
    end
  end
end
