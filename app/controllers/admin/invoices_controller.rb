class Admin::InvoicesController < Admin::BaseController
  include SortableTable
  before_filter :find_payment, only: %i[edit update]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    if params[:query] == "active"
      invoices = Invoice.active
    elsif params[:query] == "inactive"
      invoices = Invoice.inactive
    else
      invoices = Invoice
    end

    @invoices =
      invoices
        .includes(:organization, :payments, :paid_features, :first_invoice)
        .reorder(sort_column + " " + sort_direction)
        .page(page)
        .per(per_page)
    render layout: "new_admin"
  end

  protected

  def sortable_columns
    %w[id organization_id amount_cents amount_due_cents amount_paid_cents subscription_start_at subscription_end_at]
  end

  def

  def invoice_parameters
    return @invoice_parameters if defined?(@invoice_parameters)
    iparams = params.require(:payment).permit(:organization_id, :invoice_id)
    @params_invoice = Invoice.friendly_find(iparams[:invoice_id])
    if @params_invoice.present?
      iparams[:organization_id] = @params_invoice.organization_id unless iparams[:organization_id].present?
    end
    @invoice_parameters = { invoice_id: @params_invoice&.id, organization_id: iparams[:organization_id]&.to_i }
  end
end
