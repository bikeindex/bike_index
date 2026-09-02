# frozen_string_literal: true

module Pages
  module Org
    module RegistrationSequence
      module PageList
        # A sequence's pages, each collapsing to reveal its rules. An editable one
        # drags to reorder and links into each page.
        class Component < ApplicationComponent
          # editable: admin's read-only screen lists a draft without its controls
          def initialize(registration_sequence:, admin: false, editable: registration_sequence.draft?)
            @registration_sequence = registration_sequence
            @editable = editable
            @admin = admin
          end

          private

          def pages
            @pages ||= @registration_sequence.registration_sequence_pages.to_a
          end

          # Sortable only reorders an editable sequence; a frozen one has nothing to drag
          def list_data
            @editable ? {controller: "sortable"} : {}
          end

          def page_data(page)
            collapse = {controller: "ui--collapse"}
            return collapse unless @editable

            collapse.merge(sortable_target: "item", url: RegistrationSequencePaths.page(page, admin: @admin))
          end

          def edit_page_path(page) = RegistrationSequencePaths.edit_page(page, admin: @admin)
        end
      end
    end
  end
end
