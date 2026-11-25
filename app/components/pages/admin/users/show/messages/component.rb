# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        module Messages
          # Everything sent to or by one user, on the user's Messages tab. Each section is a count
          # that links to its own index, filtered to this user, over its most recent records.
          class Component < ApplicationComponent
            LIMIT = 10

            def initialize(user:)
              @user = user
            end

            private

            def records(kind) = Pages::Admin::Users::Tabs::Component.records(@user, kind)

            def recent(kind) = records(kind).reorder(created_at: :desc).limit(LIMIT)

            def counts = @counts ||= Pages::Admin::Users::Tabs::Component::MESSAGE_KINDS.to_h { [it, records(it).count] }
          end
        end
      end
    end
  end
end
