# frozen_string_literal: true

module Admin::UserCell
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(user: nil, user_id: nil, email: nil, search_url: nil, render_search: nil)
      @user = user
      @user_id = user_id || user&.id
      @email = email || user&.email
      @search_url = search_url
      @render_search = render_search.nil? ? @search_url.present? : render_search
    end

    private

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
      @user.present?
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
