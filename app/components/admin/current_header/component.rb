# frozen_string_literal: true

module Admin::CurrentHeader
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(params:, viewing: nil, kind_humanized: nil, user: nil, bike: nil, marketplace_listing: nil, primary_activity: nil, current_organization: nil)
      @params = params
      @viewing = viewing
      @kind_humanized = kind_humanized
      @user = user
      @bike = bike
      @marketplace_listing = marketplace_listing
      @primary_activity = primary_activity
      @current_organization = current_organization
    end

    private

    def viewing
      @viewing || controller_name.humanize
    end

    def header_present?
      (@params.keys & %i[user_id organization_id search_bike_id primary_activity search_kind search_marketplace_listing_id search_membership_id]).any?
    end

    def show_user?
      @params[:user_id].present?
    end

    def user_subject
      @user || User.unscoped.find_by_id(@params[:user_id])
    end

    def show_bike?
      @params[:search_bike_id].present? || @bike.present?
    end

    def bike_subject
      @bike || Bike.unscoped.find_by_id(@params[:search_bike_id])
    end

    def show_marketplace_listing?
      @params[:search_marketplace_listing_id].present? || @marketplace_listing.present?
    end

    def marketplace_listing_subject
      @marketplace_listing || MarketplaceListing.find_by_id(@params[:search_marketplace_listing_id])
    end

    def show_organization?
      @params[:organization_id].present?
    end

    def organization_subject
      @current_organization
    end

    def show_membership?
      @params[:search_membership_id].present?
    end

    def membership_id
      @params[:search_membership_id]
    end

    def show_kind?
      @params[:search_kind].present?
    end

    def kind_humanized
      @kind_humanized || @params[:search_kind]&.humanize
    end

    def show_primary_activity?
      @params[:primary_activity].present?
    end

    def primary_activity_subject
      @primary_activity || PrimaryActivity.find_by_id(@params[:primary_activity])
    end
  end
end
