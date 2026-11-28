# frozen_string_literal: true

module Pages
  module Admin
    module News
      module Form
        class ComponentPreview < ApplicationComponentPreview
          def default
            blog = Blog.where(is_listicle: false).first
            return missing_notice("blog posts") if blog.blank?

            render(Pages::Admin::News::Form::Component.new(blog:))
          end
        end
      end
    end
  end
end
