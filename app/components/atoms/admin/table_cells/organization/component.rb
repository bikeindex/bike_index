# frozen_string_literal: true

module Atoms
  module Admin
    module TableCells
      module Organization
        class Component < ApplicationComponent
          def initialize(organization: nil, organization_id: nil, search_url: nil, sort_state: ComponentStructs::SortState.new, render_search: false, short_name: false)
            @organization = organization
            @organization_id = organization_id || organization&.id
            @search_url = search_url
            @sort_state = sort_state
            @render_search = render_search
            @short_name = short_name
          end

          private

          def computed_search_url
            @computed_search_url ||= @search_url.presence ||
              (url_for(@sort_state.search_params.merge(organization_id: @organization_id)) if @sort_state.search_params.present?)
          end

          def organization_present?
            @organization_id.present?
          end

          # Memoized with defined?, since the template reads it five times and a soft-deleted
          # organization isn't in the caller's preload
          def organization_subject
            return @organization_subject if defined?(@organization_subject)

            @organization_subject = @organization.presence ||
              (::Organization.unscoped.find_by(id: @organization_id) if @organization_id.present?)
          end

          def display_name
            @short_name ? organization_subject.short_name : organization_subject.name
          end

          def error_text_class
            UI::Alerts::Base::Component::TEXT_CLASSES[:error]
          end
        end
      end
    end
  end
end
