# frozen_string_literal: true

module Admin::UserCell
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(
      user: nil,
      user_id: nil,
      email: nil,
      user_link_path: nil,
      search_url: nil,
      render_search: nil
    )
      @user = user
      @user_id = user_id || user&.id
      @email = email || user&.email
      @search_url = search_url
      @user_link_path_arg = user_link_path
      @render_search = render_search.nil? ? @search_url.present? : render_search
    end

    def render?
      @user.present? || @user_id.present? || @email.present?
    end

    private

    def user_link_path
      # bike_link_path can be false to not link
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
      @render_search && (@email.present? || @user_id.present?)
    end

    def computed_search_url
      return @search_url if @search_url.present?

      if @user_id.present?
        url_for(sortable_search_params.merge(user_id: @user_id))
      elsif @email.present?
        url_for(sortable_search_params.merge(search_email: @email))
      end
    end
  end
end
