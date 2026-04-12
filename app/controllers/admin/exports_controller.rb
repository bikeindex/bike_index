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

  def earliest_period_date
    Time.at(1535760000) # 2018-09-01
  end

  def matching_exports
    exports = if params[:organization_id].present?
      Export.where(organization_id: current_organization.id)
    else
      Export.all
    end
    exports = search_deleted_scope(exports)
    case params[:search_registrations]
    when "specific" then exports = exports.specific
    when "incomplete" then exports = exports.incompletes
    when "incompletes_and_registrations" then exports = exports.incompletes_and_registrations
    when "registered" then exports = exports.registrations
    when "impounded" then exports = exports.impounded
    end
    @stickers = Binxtils::InputNormalizer.boolean(params[:search_stickers])
    exports = exports.with_stickers if @stickers
    @with_dates = Binxtils::InputNormalizer.boolean(params[:search_with_dates])
    exports = exports.with_dates if @with_dates
    @impounded = Binxtils::InputNormalizer.boolean(params[:search_impounded])
    exports = exports.impounded if @impounded
    if params[:search_kind] == "avery"
      exports = exports.avery
    elsif params[:search_kind].present?
      exports = exports.where(kind: params[:search_kind])
    end
    exports.where(created_at: @time_range)
  end
end
