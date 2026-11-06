# frozen_string_literal: true

module MyAccounts
  class PosRegistrationMatchesController < ApplicationController
    include Sessionable

    before_action :authenticate_user_for_my_accounts_controller
    before_action :find_pos_registration_match

    def show
      render(Pages::MyAccount::PosRegistrationMatches::Show::Component.new(bike: @bike, pos_bike: @pos_bike,
        pos_registration_match: @pos_registration_match))
    end

    def update
      unless Binxtils::InputNormalizer.boolean(params[:same_bike])
        @pos_registration_match.update!(status: :declined)
        flash[:success] = translation(:kept_separate)
        return redirect_to(my_account_path)
      end

      @pos_registration_match.update!(status: :confirmed)
      if BikeServices::PosRegistrationMerger.merge(@pos_registration_match)
        flash[:success] = translation(:combined, bike_type: @pos_bike.type)
        redirect_to bike_path(@pos_bike)
      else
        flash[:notice] = translation(:couldnt_combine)
        redirect_to my_account_path
      end
    end

    private

    # Open merge candidates only, and only for the owner of both registrations
    def find_pos_registration_match
      @pos_registration_match = PosRegistrationMatch.pending.merge_candidate.find(params[:id])
      @bike = Bike.unscoped.find(@pos_registration_match.bike_id)
      @pos_bike = Bike.unscoped.find(@pos_registration_match.pos_bike_id)
      raise ActiveRecord::RecordNotFound unless [@bike, @pos_bike].all? { it.user_id == current_user.id }
    end
  end
end
