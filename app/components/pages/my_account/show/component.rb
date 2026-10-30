# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      # The signed-in user's registrations: their bikes and locks, then the three prompts
      # below them - profile, Strava and donating
      class Component < ApplicationComponent
        def initialize(user:, bikes:, pagy:, locks:, view:, locks_tab: false, page_params: {})
          @user = user
          @bikes = bikes
          @pagy = pagy
          @locks = locks.load
          @view = Pages::MyAccount::Show::BikeBox::Component::VIEWS.include?(view&.to_sym) ? view.to_sym : :list
          @locks_tab = locks_tab
          @page_params = page_params
        end

        private

        def membership = @membership ||= @user.membership_active

        def bike_count = @pagy.count

        def tabs
          [ComponentStructs::Shapes.tab(translation(".bikes"), my_account_path, active: !@locks_tab, count: bike_count),
            ComponentStructs::Shapes.tab(translation(".locks"), my_account_path(active_tab: "locks"), active: @locks_tab, count: @locks.size)]
        end

        def view_toggles
          [[:grid, "icons/lucide-layout-grid.svg", translation(".grid_view")],
            [:list, "icons/lucide-list.svg", translation(".list_view")]]
        end

        def toggle_classes(view)
          base = "tw:flex tw:size-10 tw:items-center tw:justify-center tw:rounded-lg tw:border tw:transition-colors"
          return "#{base} tw:border-purple-500 tw:bg-purple-500 tw:text-white" if view == @view

          "#{base} tw:border-gray-200 tw:bg-white tw:text-gray-500 tw:hover:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-900 tw:dark:hover:bg-gray-800"
        end

        def user_alerts = @user_alerts ||= Pages::MyAccount::Show::BikeBox::Component.user_alerts(@user)

        def unfinished_b_params = @unfinished_b_params ||= Pages::MyAccount::Show::BikeBox::Component.unfinished_b_params(@bikes)

        def bikes_with_alerts
          @bikes.select { |bike| unfinished_b_params.key?(bike.id) || user_alerts.any? { it.bike_id == bike.id } }
        end

        def link_bikes_path
          bike = @bikes.first
          edit_bike_path(bike, edit_template: "versions") if bike.present?
        end
      end
    end
  end
end
