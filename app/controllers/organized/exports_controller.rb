module Organized
  class ExportsController < Organized::BaseController
    before_action :ensure_access_to_exports!, except: [:destroy] # Because this checks ensure_admin
    before_action :find_export, only: [:show, :destroy]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @exports = exports.order(created_at: :desc).page(@page).per(@per_page)
    end

    def show; end

    def new; end

    def create
    end

    def destroy
    end

    private

    def find_export
      @export = exports.find(params[:id])
    end

    def exports
      Export.where(organization_id: current_organization.id, kind: "organization")
    end

    def ensure_access_to_exports!
      return true if current_organization.paid_for?("csv-export") || current_user.superuser?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end
  end
end
