module Api
  module V1
    class OrganizationsController < ApiV1Controller
      before_action :verify_organizations_token, only: [:show]
      skip_before_action :verify_authenticity_token

      def show
        render json: organization_serialized(@organization)
      end

      def update
        @organization = Organization.friendly_find(params[:id])
        if @organization.blank?
          redirect_to(api_v1_not_found_url) && return
        elsif params[:access_token] == @organization.access_token
          if Organization.pos_kinds.include?(params[:manual_pos_kind])
            if params[:manual_pos_kind] == "no_pos"
              @organization.update_attributes(manual_pos_kind: nil)
            else
              @organization.update_attributes(manual_pos_kind: params[:manual_pos_kind])
            end
            UpdateOrganizationPosKindWorker.perform_async(@organization.id)
            render json: organization_serialized(@organization)
          else
            message = {'406': "Not permitted POS kind"}
            render(json: message, status: 406) && return
          end
        else
          render(json: message, status: :unauthorized) && return
        end
      end

      private

      def verify_organizations_token
        @organization = Organization.friendly_find(params[:id])
        redirect_to(api_v1_not_found_url) && return unless @organization.present?
        if params[:access_token].present?
          return true if params[:access_token] == ENV["ORGANIZATIONS_API_ACCESS_TOKEN"]
          return true if params[:access_token] == @organization.access_token
        end
        message = {'401': "Not permitted"}
        respond_with(message, status: :unauthorized) && return
      end

      def organization_serialized(organization)
        {
          id: organization.id,
          name: organization.name,
          slug: organization.slug,
          can_add_bikes: organization.auto_user_id.present?,
          manual_pos_kind: organization.manual_pos_kind,
          lightspeed_register_with_phone: organization.lightspeed_register_with_phone,
          has_bike_stickers: organization.enabled?("bike_stickers")
        }
      end
    end
  end
end
