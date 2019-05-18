class Admin::AmbassadorsController < Admin::BaseController
  layout "new_admin"

  def index
    @page = params.fetch(:page, 1)
    @per_page = params.fetch(:per_page, 25)
    @ambassadors = Ambassador.all.page(@page).per(@per_page)
  end

  def show
    @ambassador = Ambassador.find(params[:id]).decorate
  end
end
