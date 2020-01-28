module Organized
  class AbandonedRecordsController < Organized::BaseController
    rescue_from ActionController::RedirectBackError, with: :redirect_back # Seth Fix for #1426

    def index
      members =
        current_organization
          .users
          .map { |u| u && [u.id.to_s, { name: u.display_name }] }
          .compact
          .to_h

      @page_data = {
        google_maps_key: ENV["GOOGLE_MAPS"],
        map_center_lat: current_organization.map_focus_coordinates[:latitude],
        map_center_lng: current_organization.map_focus_coordinates[:longitude],
        members: members,
        abandoned_root_path: organization_abandoned_records_path(organization_id: current_organization.to_param),
      }

      respond_to do |format|
        format.html
        format.json do
          render json: abandoned_records.reorder(created_at: :desc),
                 root: "abandoned_records",
                 each_serializer: AbandonedRecordSerializer
        end
      end
    end

    def show
      @abandoned_record = abandoned_records.find(params[:id])
      @bike = @abandoned_record.bike
    end

    def create
      @abandoned_record = AbandonedRecord.new(permitted_parameters)
      if @abandoned_record.save
        flash[:success] = translation(:abandoned_recorded, bike_type: @abandoned_record.bike.type)
      else
        flash[:error] = translation(:unable_to_record, errors: @abandoned_record.errors.full_messages.to_sentence)
      end
      redirect_to :back
    end

    helper_method :abandoned_records

    private

    def abandoned_records
      current_organization.abandoned_records
    end

    def permitted_parameters
      params.require(:abandoned_record).permit(:notes, :bike_id, :latitude, :longitude, :accuracy)
            .merge(user_id: current_user.id, organization_id: current_organization.id)
    end

    def ensure_access_to_abandoned_bikes!
      return true if current_organization.paid_for?("abandoned_bikes")
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      return
    end

    def redirect_back
      redirect_to organization_abandoned_records_path(organization_id: current_organization.to_param)
      return
    end
  end
end
