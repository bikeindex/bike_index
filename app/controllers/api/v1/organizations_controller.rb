module Api
  module V1
    class OrganizationsController < ApiV1Controller
      before_filter :verify_organizations_token

      def show
        organization = Organization.find_by_slug(params[:id])
        redirect_to api_v1_not_found_url and return unless organization.present?
        info = { name: organization.name, can_add_bikes: false }
        info[:can_add_bikes] = true if organization.auto_user_id.present?
        render json: info
      end

      private
      def verify_organizations_token
        unless params[:access_token].present? && params[:access_token] == ENV['ORGANIZATIONS_API_ACCESS_TOKEN']
          message = { :'401' => "Not permitted" }
          respond_with message, status: :unauthorized and return
        end
      end

    end
  end
end