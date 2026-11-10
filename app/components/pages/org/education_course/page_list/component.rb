# frozen_string_literal: true

module Pages
  module Org
    module EducationCourse
      module PageList
        # A course's pages, each collapsing to reveal its rules. An editable one
        # drags to reorder and links into each page.
        class Component < ApplicationComponent
          # editable: admin's read-only screen lists a draft without its controls
          def initialize(education_course:, admin: false, editable: education_course.draft?)
            @education_course = education_course
            @editable = editable
            @admin = admin
          end

          private

          def pages
            @pages ||= @education_course.education_course_pages.to_a
          end

          # Sortable only reorders an editable course; a frozen one has nothing to drag
          def list_data
            @editable ? {controller: "sortable"} : {}
          end

          def page_data(page)
            collapse = {controller: "ui--collapse"}
            return collapse unless @editable

            collapse.merge(sortable_target: "item", url: EducationCoursePaths.page(page, admin: @admin))
          end

          def edit_page_path(page) = EducationCoursePaths.edit_page(page, admin: @admin)
        end
      end
    end
  end
end
