# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PageList
      # A sequence's pages, each collapsing to reveal its rules. The draft's is editable -
      # drag to reorder, and a link into each page - while the active version, which
      # activation froze, is read-only.
      class Component < ApplicationComponent
        def initialize(registration_sequence:, editable: false)
          @registration_sequence = registration_sequence
          @organization = registration_sequence.organization
          @editable = editable
        end

        private

        def pages
          @pages ||= @registration_sequence.registration_sequence_pages.to_a
        end

        # Sortable only reorders the draft; the active version has nothing to drag
        def list_data
          @editable ? {controller: "sortable"} : {}
        end

        def page_data(page)
          collapse = {controller: "ui--collapse"}
          return collapse unless @editable

          collapse.merge(sortable_target: "item",
            url: organization_registration_sequence_page_path(organization_id: @organization.to_param, id: page.id))
        end

        def edit_page_path(page)
          edit_organization_registration_sequence_page_path(organization_id: @organization.to_param, id: page.id)
        end
      end
    end
  end
end
