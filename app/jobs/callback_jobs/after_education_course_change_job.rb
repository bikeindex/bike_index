# frozen_string_literal: true

module CallbackJobs
  class AfterEducationCourseChangeJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(education_course_id)
      organization_id = EducationCourse.with_deleted.find_by(id: education_course_id)&.organization_id
      # An active sequence still has rules to agree to, so they're still owed
      return if organization_id.blank? || EducationCourse.active.where(organization_id:).exists?

      EducationCourseAcknowledgment.abandon_pending(organization_id)
    end
  end
end
