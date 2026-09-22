# frozen_string_literal: true

module Atoms
  module Admin
    module TableCells
      module User
        class Component < ApplicationComponent
          # Template Dependency: UI::Alerts::Base::Component
          def initialize(
            user: nil,
            user_id: nil,
            email: nil,
            user_link_path: nil,
            search_url: nil,
            sort_state: ComponentStructs::SortState.new,
            render_search: false
          )
            @user_id = user_id || user&.id
            @user = user || (::User.unscoped.find_by(id: @user_id) if @user_id.present?)
            @email = email || @user&.email
            @search_url = search_url
            @sort_state = sort_state
            @user_link_path_arg = user_link_path
            @render_search = render_search
          end

          def render?
            @user.present? || @user_id.present? || @email.present?
          end

          private

          # Nothing about the table around it, so one fragment serves every table rendering
          # this user. The search link's arguments stay out, its href being per-request
          def cache_key
            # The render's own lookup_context: the default allocates one per call, and this
            # is called per cell rather than per page
            [self.class.cache_digest(finder: lookup_context), @user, @email, user_link_path]
          end

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
            return @user_link_path if defined?(@user_link_path)

            # user_link_path can be false to not link
            @user_link_path = if @user_link_path_arg == false
              nil
            elsif @user_link_path_arg.present?
              @user_link_path_arg
            elsif @user_id.present?
              admin_user_path(@user_id)
            end
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
            user_link_path.present? && @email.present?
          end

          def show_email_only?
            @email.present? && @user.blank?
          end

          def error_text_class
            UI::Alerts::Base::Component::TEXT_CLASSES[:error]
          end

          def deleted_user?
            @user&.deleted?
          end

          def show_search?
            @render_search && computed_search_url.present?
          end
        end
      end
    end
  end
end
