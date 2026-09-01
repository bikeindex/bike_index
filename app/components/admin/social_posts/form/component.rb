# frozen_string_literal: true

module Admin
  module SocialPosts
    module Form
      # The new social post form. Which half shows follows the kind select - sending a post
      # takes an account and a body, importing one takes the platform's ID for it.
      class Component < ApplicationComponent
        KINDS = [["Import post", "imported_post"], ["Send post", "app_post"]].freeze

        def initialize(social_post:)
          @social_post = social_post
        end

        private

        def max_character_count = Integrations::SocialPoster::TWEET_LENGTH

        def kind_fields_data(kind)
          {"admin--social-post-form-target": "kindFields", kind:}
        end

        def kind_hidden_class(kind)
          "tw:hidden" unless @social_post.kind == kind
        end

        def account_options
          SocialAccount.all.pluck(:screen_name, :id)
        end

        def repost_accounts = SocialAccount.active
      end
    end
  end
end
