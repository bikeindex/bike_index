class Admin::BulkImportsController < Admin::BaseController
  include SortableTable
  before_filter :find_bulk_import, only: [:show, :update]
  layout "new_admin"

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 10
    @bulk_imports = matching_bulk_imports.includes(:organization, :user, :creation_states)
                                         .reorder(sort_column + " " + sort_direction)
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

  helper_method :matching_bulk_imports

  protected

  def permitted_parameters
    params.require(:bulk_import).permit(%i(organization_id file no_notify))
  end

  def find_bulk_import
    @bulk_import = BulkImport.find(params[:id])
  end

  def sortable_columns
    %w[created_at progress user_id]
  end

  def matching_bulk_imports
    return @matching_bulk_imports if defined?(@matching_bulk_imports)
    bulk_imports = BulkImport
    if params[:ascend].present?
      bulk_imports = bulk_imports.ascend
    elsif params[:not_ascend].present?
      bulk_imports = bulk_imports.not_ascend
    end

    if params[:organization_id].present?
      bulk_imports = bulk_imports.where(organization_id: current_organization.id)
    end
    @matching_bulk_imports = bulk_imports
  end
end
