module Organized
  class BulkImportsController < Organized::BaseController
    include SortableTable
    skip_before_action :ensure_member!
    before_action :set_period, only: [:index]
    skip_before_action :ensure_current_organization!, only: [:create]
    skip_before_action :verify_authenticity_token, only: [:create]
    before_action :ensure_access_to_bulk_import!, except: [:create] # Because this checks ensure_admin

    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      @bulk_imports = available_bulk_imports.includes(:ownerships)
        .reorder("bulk_imports.#{sort_column} #{sort_direction}")
        .page(page).per(per_page)
      @show_kind = bulk_imports.distinct.pluck(:kind).count > 1
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
      @permitted_kinds = permitted_kinds
      @active_kind = @permitted_kinds.include?(params[:kind]) ? params[:kind] : @permitted_kinds.first
      @bulk_import ||= BulkImport.new(kind: @active_kind)
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

    helper_method :available_bulk_imports, :permitted_kinds

    private

    def bulk_imports
      BulkImport.where(organization_id: current_organization.id)
    end

    def sortable_columns
      %w[created_at kind user_id]
    end

    def available_bulk_imports
      a_bulk_imports = bulk_imports.where(created_at: @time_range, kind: permitted_kinds)
      @show_empty = !InputNormalizer.boolean(params[:without_empty])
      a_bulk_imports = a_bulk_imports.with_bikes unless @show_empty
      a_bulk_imports
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

    def permitted_kinds
      return @permitted_kinds if defined?(@permitted_kinds)
      permitted_kinds = []
      permitted_kinds += ["ascend"] if current_organization.ascend_pos?
      permitted_kinds += ["organization_import"] if current_organization.enabled?("show_bulk_import")
      permitted_kinds += ["impounded"] if current_organization.enabled?("show_bulk_import_impound")
      permitted_kinds += ["stolen"] if current_organization.enabled?("show_bulk_import_stolen")
      # Only show both types to superusers if the organization doesn't have any
      # to more closely resemble the organization interface
      if permitted_kinds.empty? && current_user.superuser?
        permitted_kinds = %w[organization_import impounded stolen]
      end
      @permitted_kinds = permitted_kinds
    end

    def permitted_parameters
      pparams = if params[:file].present?
        {file: params[:file]}
      else
        permitted_p = params.require(:bulk_import).permit(:file, :kind)
        if permitted_kinds.include?(permitted_p[:kind])
          permitted_p
        else
          permitted_p.except(:kind) # Remove kind, so it can be calculated independently
        end
      end.merge(creator_attributes)
      pparams[:kind] == "stolen" ? pparams.merge(stolen_attributes) : pparams
    end

    def creator_attributes
      if @ascend_import
        {kind: "ascend"}
      else
        {user_id: (@current_user || current_user).id, organization_id: current_organization&.id}
      end
    end

    def stolen_attributes
      {data: {stolen_record:
        params.require(:stolen_record).permit(*StolenRecordUpdator.old_attr_accessible)}}
    end
  end
end
