class Admin::InvoicesController < Admin::BaseController
  include SortableTable

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

  protected

  def sortable_columns
    %w[id organization_id amount_cents amount_due_cents amount_paid_cents subscription_start_at subscription_end_at]
  end

  def matching_invoices
    if params[:query] == "active"
      invoices = Invoice.active
    elsif params[:query] == "inactive"
      invoices = Invoice.inactive
    else
      invoices = Invoice
    end
  end
end
