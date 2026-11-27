# frozen_string_literal: true

module Pages
  module Admin
    module BugReports
      module Table
        class Component < ApplicationComponent
          COLUMNS = {
            pull_request_cell: "PR",
            sender_cell: "Sender",
            receiver_cell: "Receiver",
            subject_cell: "Subject",
            status_cell: "Status",
            tags_cell: "Tags",
            member_cell: "Member",
            invoiced_cell: "Invoiced org"
          }.freeze

          def initialize(collection:, searchable_tags:, sort_state: ComponentStructs::SortState.new, render_sortable: false)
            @collection = collection
            @searchable_tags = searchable_tags
            @sort_state = sort_state
            @render_sortable = render_sortable
          end

          private

          # The controller rewrites the search links' path to the sort state's, which off the index is the page itself
          def sortable_links_data
            return {} unless @render_sortable

            {controller: "update-cached-sortable-links", "update-cached-sortable-links-base-url-value": url_for(@sort_state.search_params)}
          end
        end
      end
    end
  end
end
