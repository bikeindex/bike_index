class Admin::ContentTagsController < Admin::BaseController
  include SortableTable
  before_action :find_content_tag, only: %i[edit update]

  def index
    @per_page = params[:per_page] || 100
    @pagy, @content_tags = pagy(matching_content_tags
      .order(sort_column + " " + sort_direction), limit: @per_page)
  end

  def new
    @content_tag ||= ContentTag.new
  end

  def show
    redirect_to edit_admin_content_tag_path
  end

  def edit
    @blogs = @content_tag.blogs.includes(:user, :content_tags)
  end

  def update
    @content_tag.update(permitted_parameters)
    flash[:success] = "Tag updated" unless flash[:error].present?
    redirect_to admin_content_tags_path
  end

  def create
    @content_tag = ContentTag.new(permitted_parameters)
    if @content_tag.save
      flash[:success] = "Tag created"
      redirect_to admin_content_tags_path
    else
      flash[:error] = "Unable to create"
      render :new
    end
  end

  helper_method :matching_content_tags

  protected

  def sortable_columns
    %w[name created_at updated_at priority]
  end

  def matching_content_tags
    ContentTag
  end

  # Because we start with alpha ordering
  def default_direction
    "asc"
  end

  def permitted_parameters
    params.require(:content_tag).permit(:name, :priority, :description)
  end

  def find_content_tag
    @content_tag = ContentTag.friendly_find(params[:id])
  end
end
