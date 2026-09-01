# frozen_string_literal: true

module Admin
  module News
    module Options
      # The blog options card on the admin news edit form - everything the post kind
      # decides, plus the fields that apply to both kinds.
      class Component < ApplicationComponent
        def initialize(form_builder:, blog:)
          @form = form_builder
          @blog = blog
        end

        private

        def blog_only_data
          {"admin--news-form-target": "blogOnly"}
        end

        def info_only_data
          {"admin--news-form-target": "infoOnly"}
        end

        def hidden_class(hidden)
          "tw:hidden" if hidden
        end

        def content_tag_options
          options_for_select(ContentTag.name_ordered.pluck(:name, :id), selected: @blog.content_tags.pluck(:id))
        end

        # The form posts a rounded value rather than whatever the browser holds
        def post_date
          Binxtils::TimeParser.round(@blog.published_at || Time.current, "seconds")
        end

        def author_needs_personal_page?
          user = User.fuzzy_email_find(@blog.user.email)
          user.blank? || user.userlink.blank?
        end
      end
    end
  end
end
