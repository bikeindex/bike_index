# frozen_string_literal: true

module Pages
  module Org
    module EducationCourse
      module PageForm
        # Adding or editing one page of a course, with the registrant's view of it below.
        class Component < ApplicationComponent
          def initialize(page:, admin: false)
            @page = page
            @education_course = page.education_course
            @admin = admin
          end

          private

          # A new page has nothing to preview or delete yet
          def editing? = @page.persisted?

          # Admin already has its own h1 on the page, so its copy of this drops a level
          def heading_options
            return {html_class: "uncap tw:mb-0!"} unless @admin

            {tag: :h2, html_class: "uncap tw:mb-0! tw:font-normal! tw:text-gray-500!"}
          end

          def form_url
            editing? ? page_path : EducationCoursePaths.pages(@education_course, admin: @admin)
          end

          def page_path = EducationCoursePaths.page(@page, admin: @admin)

          def course_path = EducationCoursePaths.edit(@education_course, admin: @admin)
        end
      end
    end
  end
end
