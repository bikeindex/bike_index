# frozen_string_literal: true

module Admin
  module News
    module Options
      # The blog options card on the admin news edit form - everything the post kind
      # decides, plus the fields that apply to both kinds.
      class Component < ApplicationComponent
        def initialize(form_builder:, blog:)
          @form_builder = form_builder
          @blog = blog
        end

        private

        def blog_only_class = ("tw:hidden" if @blog.info?)

        def info_only_class = ("tw:hidden" unless @blog.info?)

        def content_tag_options
          options_for_select(ContentTag.name_ordered.pluck(:name, :id), selected: @blog.content_tags.pluck(:id))
        end

        # step: 60 rejects a value carrying seconds
        def post_date
          Binxtils::TimeParser.round(@blog.published_at || Time.current, "seconds")
        end

        def author_needs_personal_page? = @blog.user.userlink.blank?
      end
    end
  end
end
