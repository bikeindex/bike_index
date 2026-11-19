# frozen_string_literal: true

module MyAccounts
  class PosRegistrationMatchesController < ApplicationController
    include Sessionable

    # The emailed link reaches this through the sign-in redirect, which Turbo asks to be a turbo_stream
    before_action :force_html_response, only: %i[show]
    before_action :authenticate_user_for_my_accounts_controller
    before_action :find_pos_registration_match

    ANSWERS = {"merge" => true, "decline" => false}.freeze

    def show
      return redirect_by_status unless @pos_registration_match.confirmable?

      render(Pages::MyAccount::PosRegistrationMatches::Show::Component.new(bike: @bike, pos_bike: @pos_bike,
        pos_registration_match: @pos_registration_match))
    end

    def update
      redirect_by_status(@pos_registration_match.answer!(user: current_user, merge: ANSWERS[params[:answer]]))
    end

    private

    def find_pos_registration_match
      @pos_registration_match = PosRegistrationMatch.find(params[:id])
      @bike = @pos_registration_match.bike
      @pos_bike = @pos_registration_match.pos_bike
      raise ActiveRecord::RecordNotFound unless @bike.present? && @bike.user_id == current_user.id
    end

    # The emailed link stays the same as the match changes. answered is whether the owner's answer was just recorded
    def redirect_by_status(answered = false)
      match = @pos_registration_match
      # Nothing was recorded, e.g. no answer was given
      return redirect_to(my_account_pos_registration_match_path(match)) if match.confirmable?

      key = if answered
        match.declined? ? :kept_separate : :combining_thanks
      elsif match.merging?
        :combining
      elsif match.merged?
        :already_combined
      elsif match.declined?
        :already_kept_separate
      elsif match.confirmed?
        :couldnt_combine
      else
        :cant_combine_here
      end
      flash[answered ? :success : :notice] = translation(key, bike_type: @pos_bike&.type)
      combined = (match.merging? || match.merged?) && @pos_bike&.user_id == current_user.id
      redirect_to(combined ? bike_path(@pos_bike) : my_account_path)
    end
  end
end
