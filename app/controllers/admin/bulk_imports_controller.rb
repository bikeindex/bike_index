class Admin::BulkImportsController < Admin::BaseController
  before_filter :find_bulk_import, only: [:show, :update]
  layout "new_admin"

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    if params[:organization_id].present?
      bulk_imports = BulkImport.where(organization_id: active_organization.id)
    else
      bulk_imports = BulkImport.all
    end
    @bulk_imports = bulk_imports.includes(:organization, :user, :creation_states)
                                .order(created_at: :desc).includes(:creation_states)
                                .page(page).per(per_page)
  end

  def show; end

  def new
    organization_id = Organization.friendly_find(params[:organization_id])&.id
    @bulk_import = BulkImport.new(organization_id: organization_id, no_notify: params[:no_notify])
  end

  def update
    if params[:reprocess]
      BulkImportWorker.perform_async(@bulk_import.id)
      flash[:success] = "Bulk Import enqueued for processing"
    else
      flash[:error] = "Ooooops, can't do that, how the hell did you manage to?"
    end
    redirect_to admin_bulk_import_url(@bulk_import)
  end

  def create
    @bulk_import = BulkImport.new(permitted_parameters.merge(user_id: current_user.id))
    if @bulk_import.save
      BulkImportWorker.perform_async(@bulk_import.id)
      flash[:success] = "Bulk Import created!"
      redirect_to admin_bulk_imports_url
    else
      flash[:error] = "Unable to create bulk import"
      render action: :new
    end
  end

  protected

  def permitted_parameters
    params.require(:bulk_import).permit(%i(organization_id file no_notify))
  end

  def find_bulk_import
    @bulk_import = BulkImport.find(params[:id])
  end
end
