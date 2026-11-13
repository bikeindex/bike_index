# frozen_string_literal: true

module MyAccounts
  class PosRegistrationMatchesController < ApplicationController
    include Sessionable

    before_action :authenticate_user_for_my_accounts_controller
    before_action :find_pos_registration_match

    def show
      return redirect_by_status unless @pos_registration_match.confirmable?(@bike, @pos_bike)

      render(Pages::MyAccount::PosRegistrationMatches::Show::Component.new(bike: @bike, pos_bike: @pos_bike,
        pos_registration_match: @pos_registration_match))
    end

    def update
      same_bike = Binxtils::InputNormalizer.boolean(params[:same_bike])
      # Another request may have settled it first
      return redirect_by_status unless @pos_registration_match.answer!(user: current_user, same_bike:)

      if !same_bike
        flash[:success] = translation(:kept_separate)
        redirect_to my_account_path
      elsif @pos_registration_match.merging?
        flash[:success] = translation(:combining, bike_type: @pos_bike.type)
        redirect_to bike_path(@pos_bike)
      else
        flash[:notice] = translation(:couldnt_combine)
        redirect_to my_account_path
      end
    end

    private

    def find_pos_registration_match
      @pos_registration_match = PosRegistrationMatch.find(params[:id])
      @bike = Bike.unscoped.find_by(id: @pos_registration_match.bike_id)
      @pos_bike = Bike.unscoped.find_by(id: @pos_registration_match.pos_bike_id)
      raise ActiveRecord::RecordNotFound unless @bike.present? && @bike.user_id == current_user.id
    end

    # The emailed link stays the same as the match changes
    def redirect_by_status
      if (@pos_registration_match.merged? || @pos_registration_match.merging?) && @pos_bike&.user_id == current_user.id
        flash[:notice] = @pos_registration_match.merging? ? translation(:combining) : translation(:already_combined)
        redirect_to bike_path(@pos_bike)
      else
        flash[:notice] = @pos_registration_match.declined? ? translation(:already_kept_separate) : translation(:cant_combine_here)
        redirect_to my_account_path
      end
    end
  end
end
