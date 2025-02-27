class Admin::InvoicesController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 50
    @pagy, @invoices =
      pagy(matching_invoices
        .includes(:organization, :payments, :organization_features, :first_invoice)
        .reorder(sort_column + " " + sort_direction), limit: @per_page)
  end

  helper_method :matching_invoices

  protected

  def sortable_columns
    %w[id organization_id amount_cents amount_due_cents amount_paid_cents subscription_start_at subscription_end_at]
  end

  def earliest_period_date
    Time.at(1528767966) # First invoice
  end

  def latest_period_date
    Invoice.maximum(:subscription_end_at) || Time.current
  end

  def matching_invoices
    @query = params[:query]
    invoices = if @query == "active"
      Invoice.active
    elsif @query == "inactive"
      Invoice.inactive
    elsif @query == "first_invoice"
      Invoice.first_invoice
    elsif @query == "renewal_invoice"
      Invoice.renewal_invoice
    else
      @query = nil
      Invoice
    end

    if %w[only_paid only_free].include?(params[:search_paid])
      @search_paid = params[:search_paid]
      invoices = (@search_paid == "only_paid") ? invoices.paid : invoices.free
    end

    if %w[subscription_start_at subscription_end_at].include?(params[:time_range_column])
      @time_range_column = params[:time_range_column]
      @search_endless = "not_endless" if @time_range_column == "subscription_end_at"
    else
      @time_range_column = "created_at"
    end

    if %w[endless_only not_endless].include?(params[:search_endless])
      @search_endless ||= params[:search_endless]
      invoices = (@search_endless == "endless_only") ? invoices.endless : invoices.not_endless
    end

    if current_organization.present?
      invoices = invoices.where(organization_id: current_organization.id)
    end

    invoices.where(@time_range_column => @time_range)
  end
end
