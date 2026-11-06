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
      return redirect_by_status unless @pos_registration_match.confirmable?(@bike, @pos_bike)

      unless Binxtils::InputNormalizer.boolean(params[:same_bike])
        BikeServices::PosRegistrationMerger.decline(@pos_registration_match, user: current_user)
        flash[:success] = translation(:kept_separate)
        return redirect_to(my_account_path)
      end

      if BikeServices::PosRegistrationMerger.confirm(@pos_registration_match, user: current_user)
        flash[:success] = translation(:combined, bike_type: @pos_bike.type)
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
      if @pos_registration_match.merged? && @pos_bike.present?
        flash[:notice] = translation(:already_combined)
        redirect_to bike_path(@pos_bike)
      else
        flash[:notice] = @pos_registration_match.declined? ? translation(:already_kept_separate) : translation(:cant_combine_here)
        redirect_to my_account_path
      end
    end
  end
end
