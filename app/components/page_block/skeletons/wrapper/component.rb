# frozen_string_literal: true

module PageBlock
  module Skeletons
    module Wrapper
      # The shell a page renders inside, picked from the route. Pages with no skeleton
      # lay out the full width themselves and render bare
      class Component < ApplicationComponent
        def self.skeleton_kind(controller_namespace:, controller_name:, action_name:,
          force_landing_page_render: false)
          return :organized if controller_namespace == "organized" && action_name != "landing"
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

        def initialize(controller_namespace:, controller_name:, action_name:,
          force_landing_page_render: false)
          @controller_name = controller_name
          @action_name = action_name
          @kind = self.class.skeleton_kind(controller_namespace:, controller_name:, action_name:,
            force_landing_page_render:)
        end

        # The organized skeleton renders the general alert itself, in the content column
        # the menu doesn't cover
        def organized?
          @kind == :organized
        end

        def call
          skeleton = skeleton_component
          return content if skeleton.nil?

          render(skeleton) { content }
        end

        private

        def skeleton_component
          case @kind
          when :content then content_component
          when :edit_bike then edit_bike_component
          when :oauth_applications then oauth_applications_component
          when :organized then organized_component
          end
        end

        def content_component
          PageBlock::Skeletons::Content::Component.new(
            blog: controller_ivar(:@blog),
            related_blogs: controller_ivar(:@related_blogs),
            current_user: helpers.current_user,
            controller_name: @controller_name,
            action_name: @action_name
          )
        end

        def edit_bike_component
          PageBlock::Skeletons::EditBike::Component.new(
            bike: controller_ivar(:@bike),
            bike_og: controller_ivar(:@bike_og),
            og_email: controller_ivar(:@og_email),
            edit_template: controller_ivar(:@edit_template),
            edit_templates: controller_ivar(:@edit_templates),
            current_user: helpers.current_user,
            passive_organization: helpers.passive_organization
          )
        end

        def oauth_applications_component
          PageBlock::Skeletons::OauthApplications::Component.new(
            oauth_application: controller_ivar(:@application),
            current_user: helpers.current_user,
            action_name: @action_name
          )
        end

        def organized_component
          PageBlock::Skeletons::Organized::Component.new(
            current_organization: helpers.current_organization,
            current_user: helpers.current_user,
            passive_organization: helpers.passive_organization,
            unregistered_parking_notification: controller_ivar(:@unregistered_parking_notification),
            show_general_alert: helpers.show_general_alert,
            controller_name: @controller_name,
            action_name: @action_name
          )
        end

        # Reaching into controller state, which components otherwise don't do - the layout
        # renders a skeleton on every page, so it can't pass each one's subject in
        def controller_ivar(name)
          controller.instance_variable_get(name)
        end
      end
    end
  end
end
