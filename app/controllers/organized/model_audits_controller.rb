module Organized
  class ModelAuditsController < Organized::BaseController
    include SortableTable
    before_action :ensure_access_to_model_audits!

    def index
      @page_title = "E-Vehicle Audits"
      @per_page = permitted_per_page
      @model_attestation ||= ModelAttestation.new
      @pagy, @organization_model_audits = pagy(organization_model_audits
        .reorder(sort_ordered), limit: @per_page, page: permitted_page)
    end

    def show
      @model_audit = ModelAudit.find(params[:id])
      @model_attestations = @model_audit.model_attestations
      @model_attestation ||= ModelAttestation.new
      @organization_model_audit = @model_audit.organization_model_audits.where(organization_id: current_organization.id).first
      bikes = @organization_model_audit&.bikes&.reorder(created_at: :desc) || Bike.none
      @bikes_count = @organization_model_audit&.bikes_count || 0
      @per_page = 10
      @pagy, @bikes = pagy(bikes, limit: @per_page, page: permitted_page)
    end

    # NOTE: This is really "create model_attestation"
    def create
      if !permitted_attestation_kinds.include?(permitted_parameters[:kind])
        flash[:error] = "Sorry, you can't make an attestation of that kind"
      else
        @model_attestation = ModelAttestation.new(permitted_parameters)
        if @model_attestation.save
          # Inline update to reflect the new certification_status
          current_organization.organization_model_audits
            .where(model_audit_id: @model_attestation.model_audit_id)
            .first&.update(updated_at: Time.current)
          flash[:success] = "Certification status updated successfully"
        else
          flash[:error] = "Unable to save that attestation, #{@model_attestation.errors.full_messages.to_sentence}"
        end
      end
      redirect_back(fallback_location: organization_model_audits_path(organization_id: current_organization.to_param))
    end

    private

    def sortable_columns
      %w[last_bike_created_at bikes_count certification_status mnfg_name frame_model]
    end

    def permitted_attestation_kinds
      %w[uncertified_by_trusted_org certified_by_trusted_org certification_update]
    end

    def permitted_parameters
      params.require(:model_attestation)
        .permit(:certification_type, :file, :info, :kind, :model_audit_id, :url)
        .merge(user_id: current_user.id, organization_id: current_organization.id)
    end

    def sort_ordered
      if %w[mnfg_name frame_model].include?(sort_column)
        ModelAudit.arel_table[sort_column].lower.send(sort_direction)
      else
        "organization_model_audits.#{sort_column} #{sort_direction}"
      end
    end

    def scoped_sort_column
      if %w[mnfg_name frame_model].include?(sort_column)
        "model_audits.#{sort_column}"
      else
        "organization_model_audits.#{sort_column}"
      end
    end

    def organization_model_audits
      organization_model_audits = OrganizationModelAudit.where(organization_id: current_organization.id)
        .joins(:model_audit)
      if InputNormalizer.boolean(params[:search_zero])
        @time_range_column = "updated_at" # Can't be last_bike_created_at, since it's nil
      else
        @time_range_column = "last_bike_created_at"
        organization_model_audits = organization_model_audits.where.not(bikes_count: 0)
      end
      if params[:search_mnfg_name].present?
        organization_model_audits = organization_model_audits.where(model_audits: {mnfg_name: params[:search_mnfg_name]})
      end
      organization_model_audits.where(@time_range_column => @time_range)
    end

    def ensure_access_to_model_audits!
      return true if current_organization.enabled?("model_audits") || current_user.superuser?
      raise_do_not_have_access!
    end
  end
end
