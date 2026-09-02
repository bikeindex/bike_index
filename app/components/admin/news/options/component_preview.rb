# frozen_string_literal: true

module Admin
  module News
    module Options
      class ComponentPreview < ApplicationComponentPreview
        def blog_post
          preview_for(:blog)
        end

        # An info post is published at its most recent edit, so the publish date, author
        # and canonical URL collapse away
        def info_post
          preview_for(:info)
        end

        private

        # A real Blog: the card reads its author's email and userlink, and links to the
        # post itself
        def preview_for(kind)
          blog = Blog.first
          return missing_notice("blog posts") if blog.blank?

          blog.kind = kind
          render(Admin::News::Options::Component.new(blog:, form_builder: blog_form(blog)))
        end

        def blog_form(blog)
          BikeIndexFormBuilder.new("blog", blog, template, {})
        end
      end
    end
  end
end
