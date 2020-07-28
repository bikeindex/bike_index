class Admin::InvoicesController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @invoices =
      matching_invoices
        .includes(:organization, :payments, :paid_features, :first_invoice)
        .reorder(sort_column + " " + sort_direction)
        .page(page)
        .per(per_page)
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
    invoices = if params[:query] == "active"
      Invoice.active
    elsif params[:query] == "inactive"
      Invoice.inactive
    else
      Invoice
    end

    if %w[endless_only not_endless].include?(params[:search_endless])
      @search_endless = params[:search_endless]
      invoices = @search_endless == "endless_only" ? invoices.endless : invoices.not_endless
    end

    if %w[subscription_start_at subscription_end_at].include?(params[:time_range_column])
      @time_range_column = params[:time_range_column]
      @search_endless = "endless_only"
      invoices = invoices.not_endless if @time_range_column == "subscription_end_at"
    else
      @time_range_column = "created_at"
    end

    invoices.where(@time_range_column => @time_range)
  end
end
