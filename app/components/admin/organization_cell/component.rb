# frozen_string_literal: true

module Admin
  module OrganizationCell
    class Component < ApplicationComponent
      def initialize(organization: nil, organization_id: nil, search_url: nil, sortable_search_params: nil, render_search: true)
        @organization = organization
        @organization_id = organization_id || organization&.id
        @search_url = search_url
        @sortable_search_params = sortable_search_params
        @render_search = render_search
      end

      private

      def computed_search_url
        @computed_search_url ||= @search_url.presence ||
          (url_for(@sortable_search_params.merge(organization_id: @organization_id)) if @sortable_search_params.present?)
      end

      def organization_present?
        @organization_id.present?
      end

      def organization_subject
        return @organization if @organization.present?
        Organization.unscoped.find_by(id: @organization_id) if @organization_id.present?
      end

      def error_text_class
        UI::Alerts::Base::Component::TEXT_CLASSES[:error]
      end
    end
  end
end
