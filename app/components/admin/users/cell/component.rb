# frozen_string_literal: true

module Admin
  module Users
    module Cell
      class Component < ApplicationComponent
        def initialize(
          user: nil,
          user_id: nil,
          email: nil,
          user_link_path: nil,
          search_url: nil,
          sort_state: ComponentStates::SortState.new,
          render_search: false
        )
          @user = user
          @user_id = user_id || user&.id
          @email = email || user&.email
          @search_url = search_url
          @sort_state = sort_state
          @user_link_path_arg = user_link_path
          @render_search = render_search
        end

        def render?
          @user.present? || @user_id.present? || @email.present?
        end

        private

        def computed_search_url
          @computed_search_url ||= @search_url.presence || search_url_from_params
        end

        def search_url_from_params
          return if @sort_state.search_params.blank?

          if @user_id.present?
            url_for(@sort_state.search_params.merge(user_id: @user_id))
          elsif @email.present?
            url_for(@sort_state.search_params.merge(search_email: @email))
          end
        end

        def user_link_path
          # user_link_path can be false to not link
          return if @user_link_path_arg == false
          return @user_link_path_arg if @user_link_path_arg.present?
          return admin_user_path(@user_id) if @user_id.present?

          nil
        end

        def email_display
          @email&.truncate(30)
        end

        def show_missing_user?
          @user.blank? && @user_id.present?
        end

        def show_email_for_missing_user?
          !@email.present?
        end

        def show_user_link?
          user_link_path.present?
        end

        def show_email_only?
          @email.present? && @user.blank?
        end

        def show_search?
          @render_search && computed_search_url.present?
        end
      end
    end
  end
end
