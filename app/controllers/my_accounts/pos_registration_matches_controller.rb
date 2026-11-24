# frozen_string_literal: true

module MyAccounts
  class PosRegistrationMatchesController < ApplicationController
    include Sessionable

    # The emailed link reaches this through the sign-in redirect, which Turbo asks to be a turbo_stream
    before_action :force_html_response, only: %i[show]
    before_action :authenticate_user_for_my_accounts_controller
    before_action :find_pos_registration_match

    def show
      return redirect_by_status unless @pos_registration_match.confirmable?

      render(Pages::MyAccount::PosRegistrationMatches::Show::Component.new(bike: @bike, pos_bike: @pos_bike,
        pos_registration_match: @pos_registration_match))
    end

    def update
      redirect_by_status(@pos_registration_match.answer!(user: current_user,
        merge: PosRegistrationMatch::ANSWERS[params[:answer]]))
    end

    private

    def find_pos_registration_match
      @pos_registration_match = PosRegistrationMatch.find(params[:id])
      @bike = @pos_registration_match.bike
      @pos_bike = @pos_registration_match.pos_bike
      # One the shop registered to another email is answered from there
      raise ActiveRecord::RecordNotFound unless @pos_registration_match.answerable_by?(user: current_user)
    end

    # The emailed link stays the same as the match changes. answered is whether the owner's answer was just recorded
    def redirect_by_status(answered = false)
      match = @pos_registration_match
      # Nothing was recorded, e.g. no answer was given
      return redirect_to(my_account_pos_registration_match_path(match)) if match.confirmable?

      # A really deleted POS registration (BikeDeleterJob) leaves no @pos_bike
      combined = (match.merging? || match.merged?) && @pos_bike.present? &&
        PosRegistrationMatch.owners_pos_registration?(@bike, @pos_bike)
      flash[answered ? :success : :notice] = if answered
        match.declined? ? translation(:kept_separate) : translation(:combining_thanks, bike_type: @pos_bike&.type)
      elsif match.merged?
        translation(:already_combined)
      elsif combined
        translation(:combining)
      elsif match.declined?
        translation(:already_kept_separate)
      elsif match.confirmed?
        translation(:couldnt_combine)
      else
        translation(:cant_combine_here)
      end
      redirect_to(combined ? bike_path(@pos_bike) : my_account_path)
    end
  end
end
