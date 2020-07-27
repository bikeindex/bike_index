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
    Time.at(1528767966)
  end

  def matching_invoices
    invoices = if params[:query] == "active"
      Invoice.active
    elsif params[:query] == "inactive"
      Invoice.inactive
    else
      Invoice
    end
    @search_endless = ParamsNormalizer.boolean(params[:search_endless])
    invoices = invoices.endless if @search_endless
    if %w[subscription_start_at subscription_end_at].include?(sort_column)
      @time_range_column = sort_column
    else
      @time_range_column = "created_at"
    end
    invoices = invoices.where(@time_range_column => @time_range)
  end
end
