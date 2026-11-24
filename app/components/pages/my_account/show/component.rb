# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      # The signed-in user's bikes and locks, then the prompts under them
      class Component < ApplicationComponent
        def initialize(user:, bikes:, pagy:, locks:, locks_tab: false, page_params: {})
          @user = user
          @bikes = bikes.load
          @pagy = pagy
          @locks = locks.load
          @locks_tab = locks_tab
          @page_params = page_params
        end

        private

        def membership = @membership ||= @user.membership_active

        def bike_count = @pagy.count

        def subtitle
          [translation(".bike_count", count: bike_count), translation(".lock_count", count: @locks.size),
            (translation(".membership_subtitle", level: membership.basic? ? "" : membership.level_humanized) if membership.present?)].compact.join(" · ")
        end

        def tabs
          [ComponentStructs::Shapes.tab(translation(".bikes"), my_account_path, active: !@locks_tab, count: bike_count),
            ComponentStructs::Shapes.tab(translation(".locks"), my_account_path(active_tab: "locks"), active: @locks_tab, count: @locks.size)]
        end

        def user_alerts = @user_alerts ||= Pages::MyAccount::Show::BikeBox::Component.user_alerts(@user)

        def unfinished_b_params = @unfinished_b_params ||= Pages::MyAccount::Show::BikeBox::Component.unfinished_b_params(@bikes, @user)

        def link_bikes_path
          bike = @bikes.first
          edit_bike_path(bike, edit_template: "versions") if bike.present?
        end
      end
    end
  end
end
