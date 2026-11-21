# frozen_string_literal: true

module Register
  class OrganizationsController < ApplicationController
    def show
      return redirect_to(new_register_path(organization_id: params[:organization_id]), status: :moved_permanently) unless request.format.png?

      @organization = Organization.friendly_find!(params[:organization_id])

      @qr_url = case params[:target]
      when "shop_display" then embed_organization_url(@organization, non_stolen: true, shop_display: true)
      when "landing" then "#{root_url}#{@organization.landing_page_slug || @organization.to_param}"
      else register_organization_url(@organization)
      end

      send_data RQRCode::QRCode.new(@qr_url).as_png(size: 1200, border_modules: 0).to_s, type: "image/png", disposition: "inline"
    end
  end
end
