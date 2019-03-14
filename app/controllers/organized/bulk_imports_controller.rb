module Organized
  class BulkImportsController < Organized::BaseController
    skip_before_filter :ensure_member!
    skip_before_filter :ensure_current_organization!, only: [:create]
    skip_before_filter :verify_authenticity_token, only: [:create]
    before_action :ensure_access_to_bulk_import!, except: [:create] # Because this checks ensure_admin

    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      shown_imports = bulk_imports.includes(:creation_states).order(created_at: :desc)
      @show_empty = !ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:without_empty])
      shown_imports = shown_imports.with_bikes unless @show_empty
      @bulk_imports = shown_imports.page(page).per(per_page)
    end

    def show
      @bulk_import = bulk_imports.where(id: params[:id]).first
      unless @bulk_import.present?
        flash[:error] = "Unable to find that import"
        redirect_to organization_bulk_imports_path(organization_id: current_organization.to_param) and return
      end
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      @bikes = @bulk_import.bikes.order(created_at: :desc).page(page).per(per_page)
    end

    def new
      @bulk_import = BulkImport.new
    end

    def create
      return unless ensure_can_create_import!
      @bulk_import = BulkImport.new(permitted_parameters)
      if @bulk_import.save
        BulkImportWorker.perform_async(@bulk_import.id)
        if @is_api
          render json: { success: "File imported" }, status: 201
        else
          flash[:success] = "Bulk Import created!"
          redirect_to organization_bulk_imports_path(organization_id: current_organization.to_param)
        end
      else
        if @is_api
          render json: { error: @bulk_import.errors.full_messages }
        else
          flash[:error] = "Unable to create bulk import"
          render action: :new
        end
      end
    end

    private

    def bulk_imports
      BulkImport.where(organization_id: current_organization.id)
    end

    def ensure_can_create_import!
      @is_api = request.headers["Authorization"].present?
      unless @is_api
        verify_authenticity_token
        return ensure_access_to_bulk_import!
      end

      if params[:organization_id] == "ascend"
        @ascend_import = true
        return true if request.headers["Authorization"] == BulkImport.ascend_api_token
      else
        ensure_current_organization!
        @current_user = current_organization.auto_user # Crazy override to make current user work
        return true if request.headers["Authorization"] == current_organization.access_token
      end
      render json: { error: "Not permitted" }, status: 401 and return
    end

    def ensure_access_to_bulk_import!
      return unless ensure_current_organization!
      return false unless ensure_admin! # Need to return so we don't double render
      return true if current_user.superuser? # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_organization.show_bulk_import?
      flash[:error] = "Your organization doesn't have access to that, please contact Bike Index support"
      redirect_to organization_bikes_path(organization_id: current_organization.to_param) and return
    end

    def permitted_parameters
      if params[:file].present?
        { file: params[:file] }
      else
        params.require(:bulk_import).permit([:file])
      end.merge(creator_attributes)
    end

    def creator_attributes
      if @ascend_import
        { is_ascend: true }
      else
        { user_id: (@current_user || current_user).id, organization_id: current_organization&.id }
      end
    end
  end
end
