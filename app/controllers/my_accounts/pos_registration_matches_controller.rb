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
      merge = ANSWERS[params[:answer]]
      # Only an answer from the page's buttons is recorded
      return redirect_to(my_account_pos_registration_match_path(@pos_registration_match)) if merge.nil?
      # Another request may have settled it first
      return redirect_by_status unless @pos_registration_match.answer!(user: current_user, merge:)

      if merge
        flash[:success] = translation(:combining, bike_type: @pos_bike.type)
        redirect_to bike_path(@pos_bike)
      else
        flash[:success] = translation(:kept_separate)
        redirect_to my_account_path
      end
    end

    private

    def find_pos_registration_match
      @pos_registration_match = PosRegistrationMatch.find(params[:id])
      @bike = @pos_registration_match.bike
      @pos_bike = @pos_registration_match.pos_bike
      raise ActiveRecord::RecordNotFound unless @bike.present? && @bike.user_id == current_user.id
    end

    # The emailed link stays the same as the match changes
    def redirect_by_status
      if (@pos_registration_match.merged? || @pos_registration_match.merging?) && @pos_bike&.user_id == current_user.id
        flash[:notice] = @pos_registration_match.merging? ? translation(:combining) : translation(:already_combined)
        redirect_to bike_path(@pos_bike)
      else
        flash[:notice] = if @pos_registration_match.declined?
          translation(:already_kept_separate)
        elsif @pos_registration_match.confirmed?
          translation(:couldnt_combine)
        else
          translation(:cant_combine_here)
        end
        redirect_to my_account_path
      end
    end
  end
end
