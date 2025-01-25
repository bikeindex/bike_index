# frozen_string_literal: true

class Admin::BannedEmailDomainsController < Admin::BaseController
  include SortableTable

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @banned_email_domains = BannedEmailDomain.order(sort_column => sort_direction)
      .includes(:creator)
      .page(page).per(@per_page)
  end

  def new
    @banned_email_domain = BannedEmailDomain.new
  end

  def create
    @banned_email_domain = BannedEmailDomain.new(banned_email_domain_params)
    @banned_email_domain.creator = current_user

    if BannedEmailDomain.allow_creation?(@banned_email_domain.domain)
      if @banned_email_domain.save
        flash[:success] = "New banned email domain created"
        redirect_to admin_banned_email_domains_url and return
      else
        flash.now[:error] = @banned_email_domain.errors.full_messages.to_sentence
      end
    else
      flash.now[:error] = "Doesn't seem like a new spam email domain - " \
        "not enough users with the domain or too many bikes have the domain"
    end
    render :new
  end

  private

  def banned_email_domain_params
    params.require(:banned_email_domain).permit(:domain)
  end

  def sortable_columns
    %w[created_at domain creator_id]
  end
end
