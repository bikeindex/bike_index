module Organized
  class LinesController < Organized::BaseController
    before_action :ensure_access_to_appointments!

    def index
      if current_location.present?
        redirect_to organization_line_path(current_location.to_param, organization_id: current_organization.to_param) and return
      end
    end

    def show
    end

    def update
    end

    def create
    end
  end
end
