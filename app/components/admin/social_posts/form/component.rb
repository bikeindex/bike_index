# frozen_string_literal: true

module Admin
  module SocialPosts
    module Form
      # The new social post form. Which half shows follows the kind select - sending a post
      # takes an account and a body, importing one takes the platform's ID for it.
      class Component < ApplicationComponent
        def initialize(social_post:)
          @social_post = social_post
        end

        private

        # admin.css ships .card's display unlayered, where a plain tw:hidden would lose to it
        def kind_hidden_class(kind)
          "tw:hidden!" unless @social_post.kind == kind
        end

        def account_options = SocialAccount.all.pluck(:screen_name, :id)

        def kind_options = [["Import post", "imported_post"], ["Send post", "app_post"]]
      end
    end
  end
end
