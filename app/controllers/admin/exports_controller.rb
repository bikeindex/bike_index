class Admin::ExportsController < Admin::BaseController
  def index
    @per_page = permitted_per_page(default: 10)
    exports = if params[:organization_id].present?
      Export.where(organization_id: current_organization.id)
    else
      Export.all
    end
    @pagy, @exports = pagy(exports.includes(:organization, :user).order(created_at: :desc),
      limit: @per_page, page: permitted_page)
  end
end
