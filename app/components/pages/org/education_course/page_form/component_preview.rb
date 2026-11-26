# frozen_string_literal: true

module Pages
  module Org
    module EducationCourse
      module PageForm
        class ComponentPreview < ApplicationComponentPreview
          # A saved page has the preview below it that editing marks stale
          def default
            page = editable_pages.last
            return missing_notice("education course pages") if page.blank?

            render(Pages::Org::EducationCourse::PageForm::Component.new(page:))
          end

          # Adding one POSTs, and has no preview to go stale
          def new_page
            course = organization_drafts.last
            return missing_notice("draft education courses") if course.blank?

            render(Pages::Org::EducationCourse::PageForm::Component.new(page: course.education_course_pages.new))
          end

          private

          # An activated course's pages have no editor, so their paths 404. The default
          # course's are edited in admin, so they'd render the organization's paths for it
          def organization_drafts = ::EducationCourse.draft.where.not(organization_id: nil)

          def editable_pages
            ::EducationCoursePage.where(education_course: organization_drafts)
          end
        end
      end
    end
  end
end
