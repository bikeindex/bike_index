module Api
  module V1
    class OrganizationsController < ApiV1Controller
      before_filter :verify_organizations_token

      def show
        info = { name: @organization.name, can_add_bikes: false }
        info[:can_add_bikes] = true if @organization.auto_user_id.present?
        render json: info
      end

      private
      def verify_organizations_token
        @organization = Organization.friendly_find(params[:id])
        redirect_to api_v1_not_found_url and return unless @organization.present?
        if params[:access_token].present?
          return true if params[:access_token] == ENV['ORGANIZATIONS_API_ACCESS_TOKEN']
          return true if params[:access_token] == @organization.access_token
        end
        message = { :'401' => "Not permitted" }
        respond_with message, status: :unauthorized and return
      end

    end
  end
end