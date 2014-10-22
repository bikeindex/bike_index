class Admin::BikeTokenInvitationsController < Admin::BaseController
  before_filter :find_bike_token_invitation, only: [:edit, :show, :update, :destroy]
  
  def index
    @bike_token_invitations = BikeTokenInvitation.all
  end
  
  def new
    @bike_token_invitation = BikeTokenInvitation.new
    @organizations = Organization.all
    @users = User.all
  end

  def show
  end

  def edit
    @organizations = Organization.all
  end

  def update
    if @bike_token_invitation.update_attributes(params[:bike_token_invitation])
      flash[:notice] = "Invitation Saved!"
      redirect_to admin_bike_token_invitations_url
    else
      render action: :edit
    end
  end

  def create
    @bike_token_invitation = BikeTokenInvitation.new(params[:bike_token_invitation])
    @bike_token_invitation.inviter = current_user
    if @bike_token_invitation.save
      EmailBikeTokenInvitationWorker.perform_async(@bike_token_invitation.id)
      redirect_to admin_invitations_url, notice: "#{@bike_token_invitation.invitee_email} was sent #{@bike_token_invitation.bike_token_count} #{"bike".pluralize(@bike_token_invitation.bike_token_count)}!"
    else
      flash[:error] = "Oh no! Error problem things! The invitation was not saved. Maybe we're missing some information?"
      redirect_to edit_admin_bike_token_invitation_url(@bike_token_invitation.organization.id)
    end
  end

  def destroy
    @bike_token_invitation.destroy
    redirect_to admin_bike_token_invitations_url
  end



  protected

  def find_bike_token_invitation
    @bike_token_invitation = BikeTokenInvitation.find(params[:id])
  end

end
