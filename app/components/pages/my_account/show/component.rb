# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      # The signed-in user's bikes and locks, then the prompts under them
      class Component < ApplicationComponent
        # The first is what falls back
        VIEWS = %i[list grid].freeze

        def self.permitted_view(view) = VIEWS.find { it.to_s == view.to_s } || VIEWS.first

        def initialize(user:, bikes:, pagy:, locks:, view:, locks_tab: false, page_params: {})
          @user = user
          @bikes = bikes.load
          @pagy = pagy
          @locks = locks.load
          @view = view
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

        def view_entries
          [[:grid, "icons/image.svg", translation(".grid_view")], [:list, "icons/list.svg", translation(".list_view")]].map do |view, icon, label|
            ComponentStructs::Shapes.entry(helpers.inline_svg_tag(icon, class: "tw:block tw:size-[18px]", aria_hidden: true),
              href: my_account_path(@page_params.merge(view:)), active: view == @view, title: label, aria: {label:})
          end
        end

        def user_alerts = @user_alerts ||= Pages::MyAccount::Show::BikeBox::Component.user_alerts(@user)

        def unfinished_b_params = @unfinished_b_params ||= Pages::MyAccount::Show::BikeBox::Component.unfinished_b_params(@bikes, @user)

        def bikes_with_alerts
          @bikes_with_alerts ||= @bikes.select { |bike| unfinished_b_params.key?(bike.id) || user_alerts.any? { it.bike_id == bike.id } }
        end

        def link_bikes_path
          bike = @bikes.first
          edit_bike_path(bike, edit_template: "versions") if bike.present?
        end
      end
    end
  end
end
