# frozen_string_literal: true

module Admin
  module Headers
    module Nav
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Admin::Headers::Nav::Component.new(title: "Manage Organizations"))
        end

        def with_subtitle
          render(Admin::Headers::Nav::Component.new(title: "Brakebills", subtitle: "Editing paid functionality"))
        end

        # A template, so the items can render UI:: components. The .nav-link pair is the
        # bootstrap markup the un-migrated index views still hand in
        def with_items
          {template: "admin/headers/nav/component_preview/with_items"}
        end

        def without_border
          render(Admin::Headers::Nav::Component.new(title: "Brakebills", border: false))
        end
      end
    end
  end
end
