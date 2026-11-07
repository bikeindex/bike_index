# frozen_string_literal: true

module Pages
  module Admin
    module EducationCourse
      module Header
        # Shared by every admin education-course screen: which sequence is open,
        # what's being done to it, and the switch between its three screens.
        class Component < ApplicationComponent
          ACTION_WORDS = {view: "Viewing", preview: "Previewing", edit: "Editing"}.freeze
          MODES = ACTION_WORDS.keys.freeze

          def initialize(education_course:, mode: :view)
            raise ArgumentError, "mode must be one of #{MODES.inspect}, got #{mode.inspect}" unless MODES.include?(mode)

            @education_course = education_course
            @mode = mode
          end

          private

          def action_word = ACTION_WORDS[@mode]

          # Activation freezes a sequence, so its Edit is offered but inert
          def entries
            [ComponentStructs::Shapes.entry("View",
              href: EducationCoursePaths.sequence(@education_course, admin: true), active: @mode == :view),
              ComponentStructs::Shapes.entry("Preview",
                href: EducationCoursePaths.preview(@education_course, admin: true), active: @mode == :preview),
              ComponentStructs::Shapes.entry("Edit",
                href: EducationCoursePaths.edit(@education_course, admin: true),
                active: @mode == :edit, disabled: !@education_course.draft?)]
          end

          # Archived sequences are frozen too, so name which one this is
          def uneditable_title
            return if @education_course.draft?

            "Can't edit #{@education_course.status_display.downcase} education course - create a draft"
          end

          def activate_path = EducationCoursePaths.activate(@education_course)

          def create_draft_path = EducationCoursePaths.create_draft(@education_course.organization_id)

          # What the frozen sequence offers in place of its inert Edit chip. The draft belongs
          # to the owner rather than to this sequence, so a second archived one points at it too
          def create_draft_text
            return "Edit draft" if ::EducationCourse.existing_draft_for(@education_course.organization).present?

            "Create draft"
          end

          def activate_confirm
            "Make this the live #{@education_course.badge_name} education course? " \
              "It can't be edited afterward."
          end

          # The template has no organization to view it in
          def organization_sequence_path
            return if @education_course.template?

            EducationCoursePaths.sequence(@education_course)
          end
        end
      end
    end
  end
end
