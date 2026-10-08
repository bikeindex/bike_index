module Organized
  class OrganizationMessagesController < Organized::BaseController
    def create
      organization_message = current_organization.organization_messages
        .new(permitted_parameters.merge(sender: current_user))
      if organization_message.save
        flash[:success] = translation(:sent)
      else
        flash[:error] = translation(:unable_to_send, errors: organization_message.errors.full_messages.to_sentence)
      end
      redirect_back(fallback_location: bike_path(organization_message.bike_id))
    end

    private

    def permitted_parameters
      params.require(:organization_message).permit(:bike_id, :message)
    end
  end
end
