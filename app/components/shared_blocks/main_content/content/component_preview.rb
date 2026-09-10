# frozen_string_literal: true

module SharedBlocks
  module MainContent
    module Content
      class ComponentPreview < ApplicationComponentPreview
        # @display legacy_stylesheet true
        def default
          render(component(controller_name: "info", action_name: "about")) { placeholder }
        end

        # The news menu, rather than the informational pages one
        # @display legacy_stylesheet true
        def news
          render(component(controller_name: "news", action_name: "index")) { placeholder }
        end

        private

        def component(controller_name:, action_name:)
          SharedBlocks::MainContent::Content::Component.new(blog: nil, related_blogs: nil,
            source: nil, current_user: nil, controller_name:, action_name:)
        end

        def placeholder
          "<h1>Page title</h1><p>The page renders here.</p>".html_safe
        end
      end
    end
  end
end
