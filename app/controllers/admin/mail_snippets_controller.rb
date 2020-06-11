class Admin::MailSnippetsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  before_action :find_snippet, except: [:index, :new, :create]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @mail_snippets = matching_mail_snippets.reorder("mail_snippets.#{sort_column} #{sort_direction}")
                        .page(page).per(per_page)
                        .includes(:organization)
  end

  def show
    redirect_to edit_admin_mail_snippet_url(@mail_snippet)
  end

  def edit
    @organizations = Organization.all
  end

  def update
    if @mail_snippet.update_attributes(permitted_parameters)
      flash[:success] = "Snippet Saved!"
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :edit
    end
  end

  def new
    @mail_snippet = MailSnippet.new
    @organizations = Organization.all
  end

  def create
    @mail_snippet = MailSnippet.create(permitted_parameters)
    if @mail_snippet.save
      flash[:success] = "Snippet Created!"
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :new
    end
  end

  helper_method :matching_mail_snippets

  protected

  def sortable_columns
    %w[created_at organization_id updated_at kind]
  end

  def matching_mail_snippets
    return @matching_mail_snippets if defined?(@matching_mail_snippets)
    matching_mail_snippets = MailSnippet
    if MailSnippet.kinds.include?(params[:search_kind])
      @search_kind = params[:search_kind]
      matching_mail_snippets = matching_mail_snippets.where(kind: @search_kind)
    else
      @search_kind = "all"
    end
    if current_organization.present?
      matching_mail_snippets = matching_mail_snippets.where(organization_id: current_organization.id)
    end
    @matching_mail_snippets = matching_mail_snippets.where(created_at: @time_range)
  end

  def permitted_parameters
    params.require(:mail_snippet).permit(:name, :body, :is_enabled, :address,
                                         :is_location_triggered, :proximity_radius)
  end

  def find_snippet
    @mail_snippet = MailSnippet.find(params[:id])
  end
end
