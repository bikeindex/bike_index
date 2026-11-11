# frozen_string_literal: true

module CallbackJobs
  class AfterEducationCourseChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(education_course_id)
      education_course = EducationCourse.with_deleted.find_by(id: education_course_id)
      return if education_course.blank?

      # nil for the template, which owns its own pending acknowledgments.
      # An active course still has rules to agree to, so they're still owed
      organization_id = education_course.organization_id
      return if EducationCourse.active.where(organization_id:).exists?

      EducationCourseAcknowledgment.abandon_pending(organization_id)
    end
  end
end
