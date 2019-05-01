module Organized
  class MessagesController < Organized::BaseController
    rescue_from ActionController::RedirectBackError, with: :redirect_back # Gross. TODO: Rails 5 update
    before_action :ensure_permitted_message_kind!, only: %i[index create]

    def index
      respond_to do |format|
        format.html
        format.json do
          render json: organization_messages.reorder(created_at: :desc),
                 root: "messages",
                 each_serializer: OrganizedMessageSerializer
        end
      end
    end

    def show
      @organization_message = organization_messages.find(params[:id])
      @bike = @organization_message.bike
    end

    def create
      @organization_message = OrganizationMessage.new(permitted_parameters)
      if @organization_message.save
        flash[:success] = "#{@organization_message.kind} message sent"
      else
        flash[:error] = "Unable to send message - #{@organization_message.errors.full_messages.to_sentence}"
      end
      redirect_to :back
    end

    helper_method :organization_messages

    private

    def organization_messages
      current_organization.organization_messages
    end

    def ensure_permitted_message_kind!
      @kind = params[:organization_message].present? ? params[:organization_message][:kind_slug] : params[:kind]
      @kind ||= current_organization.message_kinds
      return true if current_organization.paid_for?(@kind)
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      if current_organization.message_kinds.any?
        redirect_to organization_messages_path(organization_id: current_organization.to_param, kind: current_organization.message_kinds.first)
      else
        redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      end
      return
    end

    def permitted_parameters
      params.require(:organization_message).permit(:kind_slug, :body, :bike_id, :latitude, :longitude, :accuracy)
            .merge(sender_id: current_user.id, organization_id: current_organization.id)
    end

    def redirect_back
      redirect_kind = @kind || current_organization.message_kinds.first
      redirect_to organization_messages_path(organization_id: current_organization.to_param, kind: redirect_kind)
      return
    end
  end
end
