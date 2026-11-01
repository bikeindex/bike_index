# frozen_string_literal: true

module Pages
  module Admin
    module Users
      module Show
        module Bikes
          # The user's Bikes tab: their most recent bikes, leaving the rest to the admin bikes index
          class Component < ApplicationComponent
            LIMIT = 100

            def initialize(user:)
              @user = user
            end

            private

            def records = Pages::Admin::Users::Tabs::Component.records(@user, :bikes)

            def bikes
              records.includes(:creation_organization, :current_ownership, :current_impound_record, :paint)
                .reorder(id: :desc).limit(LIMIT)
            end

            def bikes_count = @bikes_count ||= records.count

            def deleted_bikes_count = @deleted_bikes_count ||= Bike.unscoped.current_owner(@user.id).only_deleted.count

            def index_note
              note = (bikes_count > LIMIT) ? "first #{LIMIT} shown, view all in " : "view in "
              safe_join(["(", note, link_to("admin/bikes", admin_bikes_path(user_id: @user.id), class: "twlink"), ")"])
            end
          end
        end
      end
    end
  end
end
