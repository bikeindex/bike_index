# frozen_string_literal: true

# Answering a match the shop registered to another email, from the token emailed to it - which may have no account
class PosRegistrationMatchesController < ApplicationController
  before_action :find_pos_registration_match

  def show
    # Moved to the session, so the token isn't in the page's URL for its analytics to see. Kept per match, so
    # another match's link doesn't replace it
    if params[:token].present?
      session[:pos_registration_match_tokens] = session_tokens.merge(@pos_registration_match.id.to_s => params[:token])
      return redirect_to(pos_registration_match_path(@pos_registration_match))
    end
    return redirect_by_status unless @pos_registration_match.confirmable?

    render(Pages::MyAccount::PosRegistrationMatches::Show::Component.new(bike: @pos_registration_match.bike,
      pos_bike: @pos_registration_match.pos_bike, pos_registration_match: @pos_registration_match))
  end

  def update
    redirect_by_status(@pos_registration_match.answer!(merge: PosRegistrationMatch::ANSWERS[params[:answer]],
      token: session_tokens[@pos_registration_match.id.to_s], user: current_user))
  end

  private

  def find_pos_registration_match
    @pos_registration_match = PosRegistrationMatch.find(params[:id])
    token = params[:token].presence || session_tokens[@pos_registration_match.id.to_s]
    raise ActiveRecord::RecordNotFound unless @pos_registration_match.different_email? &&
      @pos_registration_match.answerable_by?(token:)
  end

  def session_tokens = session[:pos_registration_match_tokens] || {}

  # The emailed link stays the same as the match changes. answered is whether the answer was just recorded
  def redirect_by_status(answered = false)
    match = @pos_registration_match
    # Nothing was recorded, e.g. no answer was given
    return redirect_to(pos_registration_match_path(match)) if match.confirmable?

    flash[answered ? :success : :notice] = if answered
      match.declined? ? translation(:kept_separate) : translation(:combining_thanks)
    elsif match.merged? || match.merging?
      translation(:already_combined)
    elsif match.declined?
      translation(:already_kept_separate)
    else
      translation(:cant_combine_here)
    end
    redirect_to root_path
  end
end
