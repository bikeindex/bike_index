# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Table
        # The admin organizations index table, also rendered on the admin dashboard.
        class Component < ApplicationComponent
          def initialize(organizations:, sort_state: ComponentStructs::SortState.new,
            render_sortable: false, render_deleted: false)
            @organizations = organizations
            @sort_state = sort_state
            @render_sortable = render_sortable
            @render_deleted = render_deleted
          end

          private

          def pos_link(organization)
            display = organization.pos_kind.to_s.gsub("pos", "")

            # A fixed path rather than the current search params, which the row cache would bake in
            path = admin_organizations_path(search_pos: organization.pos_kind)
            return link_to(display.humanize, path, class: "text-warning") if display.match?("broken")

            render(UI::ButtonLink::Component.new(href: path, text: display.humanize, color: :link_gray))
          end
        end
      end
    end
  end
end
