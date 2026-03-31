class Admin::ExportsController < Admin::BaseController
  before_action :set_period, only: [:index]

  def index
    @per_page = permitted_per_page(default: 10)
    @pagy, @collection = pagy(:countish,
      matching_exports.includes(:organization, :user).order(created_at: :desc),
      limit: @per_page, page: permitted_page)
  end

  helper_method :matching_exports

  private

  def matching_exports
    exports = if params[:organization_id].present?
      Export.where(organization_id: current_organization.id)
    else
      Export.all
    end
    @deleted = Binxtils::InputNormalizer.boolean(params[:search_deleted])
    exports = exports.deleted if @deleted
    exports.where(created_at: @time_range)
  end
end
