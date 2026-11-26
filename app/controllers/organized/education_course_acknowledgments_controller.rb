module Organized
  class EducationCourseAcknowledgmentsController < Organized::BaseController
    include Binxtils::SortableTable

    before_action :ensure_access_to_education_courses!

    def index
      status = params[:search_status].presence_in(Pages::Org::EducationCourseAcknowledgments::Index::Component::STATUSES)
      pagy, acknowledgments = pagy(:countish, matching_acknowledgments(status)
        .preload(:bike, education_course: :organization).reorder(sortable_order((sort_column == "created_at") ? Bike : EducationCourseAcknowledgment)),
        limit: permitted_per_page, page: permitted_page)

      render Pages::Org::EducationCourseAcknowledgments::Index::Component.new(pagy:, acknowledgments:,
        organization: current_organization, sort_state:, status:, period: @period, start_time: @start_time, end_time: @end_time)
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

    def ensure_access_to_education_courses!
      return true if current_organization.enabled?("education_courses") || current_user.superuser?

      raise_do_not_have_access!
    end
  end
end
