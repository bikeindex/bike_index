# frozen_string_literal: true

module Pages
  module Admin
    module News
      module Form
        # The admin news edit form: writing in the main column, publishing and metadata in a
        # sidebar. Pages::Admin::News::Options is the legacy layout's equivalent of the sidebar.
        class Component < ApplicationComponent
          def initialize(blog:)
            @blog = blog
          end

          private

          def blog_only_class = ("tw:hidden" if @blog.info?)

          def info_only_class = ("tw:hidden" unless @blog.info?)

          def content_tag_options = ContentTag.name_ordered.pluck(:name)

          # step: 60 rejects a value carrying seconds
          def post_date
            Binxtils::TimeParser.round(@blog.published_at || Time.current, "seconds")
          end

          def author_needs_personal_page? = @blog.user.userlink.blank?

          def status_badge = @blog.published? ? UI::Badge::Component.new(text: "Published", color: :success) : UI::Badge::Component.new(text: "Draft", color: :gray)
        end
      end
    end
  end
end
