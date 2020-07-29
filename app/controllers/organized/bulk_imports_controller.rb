module Organized
  class BulkImportsController < Organized::BaseController
    skip_before_action :ensure_member!
    skip_before_action :ensure_current_organization!, only: [:create]
    skip_before_action :verify_authenticity_token, only: [:create]
    before_action :ensure_access_to_bulk_import!, except: [:create] # Because this checks ensure_admin

    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      shown_imports = bulk_imports.includes(:creation_states).order(created_at: :desc)
      @show_empty = !ParamsNormalizer.boolean(params[:without_empty])
      shown_imports = shown_imports.with_bikes unless @show_empty
      @bulk_imports = shown_imports.page(page).per(per_page)
    end

    def show
      @bulk_import = bulk_imports.where(id: params[:id]).first
      unless @bulk_import.present?
        flash[:error] = translation(:unable_to_find_import)
        redirect_to(organization_bulk_imports_path(organization_id: current_organization.to_param)) && return
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
          render json: {success: translation(:file_imported)}, status: 201
        else
          flash[:success] = translation(:bulk_import_created)
          redirect_to organization_bulk_imports_path(organization_id: current_organization.to_param)
        end
      elsif @is_api
        render json: {error: @bulk_import.errors.full_messages}
      else
        flash[:error] = translation(:unable_to_create_bulk_import)
        render action: :new
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
      render(json: {error: "Not permitted"}, status: 401) && return
    end

    def ensure_access_to_bulk_import!
      return unless ensure_current_organization!

      # Need to return so we don't double render
      return false unless ensure_admin!

      # ensure_admin! passes with superuser - this allow superuser to see even if org not enabled
      return true if current_user.superuser? || current_organization.show_bulk_import?

      flash[:error] = translation(:org_does_not_have_access)
      redirect_to(organization_root_path) && return
    end

    def permitted_parameters
      if params[:file].present?
        {file: params[:file]}
      else
        params.require(:bulk_import).permit([:file])
      end.merge(creator_attributes)
    end

    def creator_attributes
      if @ascend_import
        {is_ascend: true}
      else
        {user_id: (@current_user || current_user).id, organization_id: current_organization&.id}
      end
    end
  end
end
