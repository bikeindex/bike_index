# frozen_string_literal: true

class Admin::EmailDomainsController < Admin::BaseController
  include SortableTable
  before_action :find_email_domain, only: %i[show update]

  def index
    @per_page = params[:per_page] || 25

    @pagy, @email_domains = pagy(
      matching_email_domains.includes(:creator).reorder("email_domains.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def new
    @email_domain = EmailDomain.new
  end

  def create
    @email_domain = EmailDomain.new(email_domain_params)
    @email_domain.creator = current_user

    if @email_domain.banned? && !EmailDomain.allow_domain_ban?(@email_domain.domain)
      flash.now[:error] = domain_ban_message(@email_domain.domain)
    elsif @email_domain.save
      flash[:success] = "New email domain created"
      redirect_to admin_email_domains_url and return
    else
      flash.now[:error] = @email_domain.errors.full_messages.to_sentence
    end
    render :new
  end

  def show
  end

  def edit
    redirect_to admin_email_domain_path
  end

  def update
    # Only check if allowed to make banned if the domain isn't banned already
    if !@email_domain.banned? && permitted_update_parameters[:status] == "banned" &&
        !EmailDomain.allow_domain_ban?(@email_domain.domain)

      flash.now[:error] = domain_ban_message(@email_domain.domain)
    elsif @email_domain.update(permitted_update_parameters)
      flash[:success] = "Domain Saved!"
      redirect_to admin_membership_url(@email_domain) and return
    end

    render action: :show
  end

  private

  def sortable_columns
    %w[created_at updated_at domain creator_id status user_count]
  end

  def find_email_domain
    @email_domain = EmailDomain.find(params[:id])
  end

  def matching_email_domains
    email_domains = EmailDomain
    @show_matching_users = InputNormalizer.boolean(params[:search_matching_users])
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"

    email_domains.where(@time_range_column => @time_range)
  end

  def permitted_update_parameters
    params.require(:email_domain).permit(:status)
  end

  def email_domain_params
    params.require(:email_domain).permit(:domain, :status)
  end

  def domain_ban_message(domain)
    "Doesn't seem like a new spam email domain - " + if EmailDomain.too_many_bikes?(domain)
      "Too many bikes"
    else
      "not enough users with the domain"
    end
  end
end
