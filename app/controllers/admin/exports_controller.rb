class Admin::ExportsController < Admin::BaseController
  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    if params[:organization_id].present?
      exports = Export.where(organization_id: current_organization.id)
    else
      exports = Export.all
    end
    @exports = exports.includes(:organization, :user).order(created_at: :desc)
                      .page(page).per(per_page)
  end
end
