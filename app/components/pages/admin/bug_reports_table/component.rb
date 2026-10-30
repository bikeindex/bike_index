# frozen_string_literal: true

module Pages
  module Admin
    module BugReportsTable
      class Component < ApplicationComponent
        COLUMNS = {
          sender_cell: "Sender",
          receiver_cell: "Receiver",
          subject_cell: "Subject",
          status_cell: "Status",
          tags_cell: "Tags",
          member_cell: "Member",
          invoiced_cell: "Invoiced org",
          pull_request_cell: "PR"
        }.freeze

        def initialize(collection:, searchable_tags:, sort_state: ComponentStructs::SortState.new, render_sortable: false)
          @collection = collection
          @searchable_tags = searchable_tags
          @sort_state = sort_state
          @render_sortable = render_sortable
        end
      end
    end
  end
end
