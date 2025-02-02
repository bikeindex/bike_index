class Admin::ExportsController < Admin::BaseController
  def index
    @per_page = params[:per_page] || 10
    exports = if params[:organization_id].present?
      Export.where(organization_id: current_organization.id)
    else
      Export.all
    end
    @pagy, @exports = pagy(exports.includes(:organization, :user).order(created_at: :desc),
      limit: @per_page)
  end
end
