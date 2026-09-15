# frozen_string_literal: true

module Pages
  module Admin
    module PublicImages
      module Uploader
        # The admin image list and its uploader, for every imageable that has an admin page:
        # PublicImagesController#create reads the param named here to find the imageable back.
        class Component < ApplicationComponent
          def initialize(imageable:, list_class:)
            @imageable = imageable
            @list_class = list_class
          end

          private

          # Organization is found by slug, the others by id -- and Blog#to_param is its slug
          def upload_params
            case @imageable
            when Blog then {blog_id: @imageable.id}
            when MailSnippet then {mail_snippet_id: @imageable.id}
            when Organization then {organization_id: @imageable.to_param}
            else raise ArgumentError, "no public_images param for #{@imageable.class}"
            end
          end
        end
      end
    end
  end
end
