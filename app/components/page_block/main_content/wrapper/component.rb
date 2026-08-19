# frozen_string_literal: true

module PageBlock
  module MainContent
    module Wrapper
      # The wrapper a page's main content renders inside, picked from the route. Pages
      # with no wrapper lay out the full width themselves and render bare
      class Component < ApplicationComponent
        def self.kind(controller_namespace:, controller_name:, action_name:,
          force_landing_page_render: false, register_flow_organization_id: nil)
          return :organized if controller_namespace == "organized" && action_name != "landing"
          # The register flow, when the registration it's on belongs to an organization
          return :organized if register_flow_organization_id.present?
          return :oauth_applications if controller_namespace == "oauth" && controller_name == "applications"
          return nil if controller_namespace == "search" || force_landing_page_render

          case controller_name
          when "bikes"
            :edit_bike if action_name == "update"
          when "edits", "theft_alerts", "recovery"
            :edit_bike
          when "info"
            :content unless %w[terms security vendor_terms privacy support_the_index resources].include?(action_name)
          when "welcome"
            :content if action_name == "goodbye"
          when "organizations"
            :content if action_name == "lightspeed_integration"
          when "news", "feedbacks", "manufacturers", "errors"
            :content
          when "registrations"
            :content unless action_name == "show"
          end
        end

        # Every wrapper's subject, since the layout renders this before knowing which
        # wrapper it gets - only the matched one's args are read
        def initialize(controller_namespace:, controller_name:, action_name:,
          force_landing_page_render: false, current_user: nil, current_organization: nil,
          passive_organization: nil, show_general_alert: false, blog: nil, related_blogs: nil,
          bike: nil, bike_og: nil, og_email: nil, edit_template: nil, edit_templates: nil,
          oauth_application: nil, source: nil, old_register_view: false,
          register_flow_organization_id: nil)
          @controller_namespace = controller_namespace
          @controller_name = controller_name
          @action_name = action_name
          @current_user = current_user
          @current_organization = current_organization
          @passive_organization = passive_organization
          @show_general_alert = show_general_alert
          @blog = blog
          @related_blogs = related_blogs
          @bike = bike
          @bike_og = bike_og
          @og_email = og_email
          @edit_template = edit_template
          @edit_templates = edit_templates
          @oauth_application = oauth_application
          @source = source
          @old_register_view = old_register_view
          @register_flow_organization_id = register_flow_organization_id
          @kind = self.class.kind(controller_namespace:, controller_name:, action_name:,
            force_landing_page_render:, register_flow_organization_id:)
        end

        def call
          wrapper = case @kind
          when :content then content_component
          when :edit_bike then edit_bike_component
          when :oauth_applications then oauth_applications_component
          when :organized then organized_component
          end
          return content if wrapper.nil?

          render(wrapper) { content }
        end

        private

        def content_component
          PageBlock::MainContent::Content::Component.new(
            blog: @blog,
            related_blogs: @related_blogs,
            source: @source,
            current_user: @current_user,
            controller_name: @controller_name,
            action_name: @action_name
          )
        end

        def edit_bike_component
          PageBlock::MainContent::EditBike::Component.new(
            bike: @bike,
            bike_og: @bike_og,
            og_email: @og_email,
            edit_template: @edit_template,
            edit_templates: @edit_templates,
            current_user: @current_user,
            passive_organization: @passive_organization
          )
        end

        def oauth_applications_component
          PageBlock::MainContent::OauthApplications::Component.new(
            oauth_application: @oauth_application,
            current_user: @current_user,
            action_name: @action_name
          )
        end

        def organized_component
          PageBlock::MainContent::Organized::Component.new(
            current_organization: @current_organization,
            current_user: @current_user,
            passive_organization: @passive_organization,
            show_general_alert: @show_general_alert,
            controller_namespace: @controller_namespace,
            controller_name: @controller_name,
            action_name: @action_name,
            old_register_view: @old_register_view,
            register_flow_organization_id: @register_flow_organization_id
          )
        end
      end
    end
  end
end
