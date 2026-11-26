module Organized
  class EducationCourseAcknowledgmentsController < Organized::BaseController
    include Binxtils::SortableTable

    before_action :ensure_access_to_education_courses!

    def index
      pagy, acknowledgments = pagy(:countish,
        EducationCourseAcknowledgment.acknowledged.for_organization_bikes(current_organization)
          .preload(:bike, education_course: :organization).reorder(sortable_order(EducationCourseAcknowledgment)),
        limit: permitted_per_page, page: permitted_page)

      render Pages::Org::EducationCourseAcknowledgments::Index::Component.new(pagy:, acknowledgments:,
        organization: current_organization, sort_state:)
    end

    private

    def sortable_columns
      %w[acknowledged_at owner_email].freeze
    end

    def ensure_access_to_education_courses!
      return true if current_organization.enabled?("education_courses") || current_user.superuser?

      raise_do_not_have_access!
    end
  end
end
