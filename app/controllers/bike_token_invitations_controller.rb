class BikeTokenInvitationsController < ApplicationController
  before_filter :ensure_user_can_invite!
  
  def create
    @bike_token_invitation = BikeTokenInvitation.new(params[:bike_token_invitation])
    @bike_token_invitation.inviter = current_user
    if @bike_token_invitation.save
      EmailBikeTokenInvitationWorker.perform_async(@bike_token_invitation.id)
      flash[:notice] = "#{@bike_token_invitation.invitee_email} was sent #{@bike_token_invitation.bike_token_count} #{"bike".pluralize(@bike_token_invitation.bike_token_count)}!"
      redirect_to user_home_url

    else
      flash[:notice] = "Oh no! Error problem things! The invitation was not saved. Maybe we're missing some information?"
      redirect_to user_home_url
    end
  end

  protected

  def ensure_user_can_invite!
    unless current_user.can_invite && current_user.has_membership?
      flash[:notice] = "You're not allowed to send free bike tokens!"
      redirect_to user_home_url
    end
  end

end
