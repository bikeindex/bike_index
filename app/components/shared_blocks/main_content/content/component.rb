# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module Content
      # The two column shell for the informational pages, with a menu of related pages -
      # or a donation ask - beside them
      class Component < ApplicationComponent
        def initialize(blog:, related_blogs:, source:, current_user:, controller_name:, action_name:)
          @blog = blog
          @related_blogs = related_blogs
          @source = source
          @current_user = current_user
          @controller_name = controller_name
          @action_name = action_name
        end

        private

        # Which menu items to display
        def content_page_type
          if @controller_name == "info"
            @action_name
          elsif @controller_name == "news"
            "news"
          end
        end

        def render_why_donate?
          @blog&.title_slug == Blog.why_donate_slug
        end

        def render_get_your_stolen_bike_back?
          @blog&.title_slug == Blog.get_your_stolen_bike_back_slug
        end

        # Only reached from the why-donate post, which the donation funnel counts under
        # "why-donate" rather than under its own long slug
        def referral_source
          @source.presence || "why-donate"
        end
      end
    end
  end
end
