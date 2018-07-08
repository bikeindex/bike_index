module Organized
  class BulkImportsController < Organized::BaseController
    before_action :ensure_access_to_bulk_import!

    def index
      @bulk_imports = bulk_imports.includes(:creation_states).order(created_at: :desc)
    end

    def show
      @bulk_import = bulk_imports.find(params[:id])
    end

    def new
      @bulk_import = BulkImport.new
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

    private

    def bulk_imports
      BulkImport.where(organization_id: current_organization.id)
    end

    def ensure_access_to_bulk_import!
      return true if current_user.superuser?
      return true if ensure_admin! && current_organization.show_bulk_import
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end

    def permitted_parameters
      params.require(:bulk_import).permit(%i[file no_notify])
    end
  end
end
