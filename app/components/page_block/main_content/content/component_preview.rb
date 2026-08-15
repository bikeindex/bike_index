# frozen_string_literal: true

module PageBlock
  module MainContent
    module Content
      class ComponentPreview < ApplicationComponentPreview
        # @display legacy_stylesheet true
        def default
          render(PageBlock::MainContent::Content::Component.new(blog: nil, related_blogs: nil,
            current_user: nil, controller_name: "info", action_name: "about")) { placeholder }
        end

        # The news menu, rather than the informational pages one
        # @display legacy_stylesheet true
        def news
          render(PageBlock::MainContent::Content::Component.new(blog: nil, related_blogs: nil,
            current_user: nil, controller_name: "news", action_name: "index")) { placeholder }
        end

        private

        def placeholder
          "<h1>Page title</h1><p>The page renders here.</p>".html_safe
        end
      end
    end
  end
end
