# frozen_string_literal: true

class Admin::EmailDomainsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 25
    @pagy, @email_domains = pagy(EmailDomain.order(sort_column => sort_direction)
      .includes(:creator), limit: @per_page)
  end

  def new
    @email_domain = EmailDomain.new
  end

  def create
    @email_domain = EmailDomain.new(email_domain_params)
    @email_domain.creator = current_user

    if EmailDomain.allow_creation?(@email_domain.domain)
      if @email_domain.save
        flash[:success] = "New banned email domain created"
        redirect_to admin_email_domains_url and return
      else
        flash.now[:error] = @email_domain.errors.full_messages.to_sentence
      end
    else
      flash.now[:error] = "Doesn't seem like a new spam email domain - " \
        "not enough users with the domain or too many bikes have the domain"
    end
    render :new
  end

  def destroy
    @email_domain = EmailDomain.find(params[:id])
    @email_domain.destroy
    flash[:success] = "Ban removed"
    redirect_back(fallback_location: admin_email_domains_path)
  end

  private

  def email_domain_params
    params.require(:email_domain).permit(:domain)
  end

  def sortable_columns
    %w[created_at domain creator_id]
  end
end
