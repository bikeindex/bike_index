class Admin::NewsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_blog, only: [:show, :edit, :update, :destroy]
  before_action :set_dignified_name

  def index
    @blogs = available_blogs.reorder(sort_column + " " + sort_direction)
      .includes(:user, :content_tags)
  end

  def new
    @blog = Blog.new(published_at: Time.current, user_id: current_user.id)
  end

  def image_edit
    @listicle = Listicle.find(params[:id])
    @blog = @listicle.blog
  end

  def show
    redirect_to edit_admin_news_url
  end

  def edit
    @page_title = "Edit: #{@blog.title}"
  end

  def update
    if @blog.update(permitted_parameters)
      @blog.reload

      if @blog.listicles.present?
        @blog.listicles.pluck(:id).each { |id| ListicleImageSizeJob.perform_in(1.minutes, id) }
      end

      flash[:success] = "#{@blog.info? ? "Info post" : "Blog"} saved!"
      redirect_to edit_admin_news_url(@blog)
    else
      render action: :edit
    end
  end

  def create
    @blog = Blog.create({
      title: params[:blog][:title],
      user_id: current_user.id,
      body: "No content yet, write some now!",
      published_at: Time.current,
      is_listicle: false
    })
    if @blog.save
      flash[:success] = "#{@blog.info? ? "Info post" : "Blog"} created!"
      redirect_to edit_admin_news_url(@blog)
    else
      flash[:error] = "#{@blog.info? ? "Info post" : "Blog"} error! #{@blog.errors.full_messages.to_sentence}"
      redirect_to new_admin_news_path
    end
  end

  def destroy
    @blog.destroy
    redirect_to admin_news_index_url
  end

  helper_method :available_blogs

  protected

  def sortable_columns
    %w[created_at published_at user_id updated_at title]
  end

  def permitted_parameters
    params.require(:blog).permit(
      :body,
      :canonical_url,
      :description_abbr,
      :index_image,
      :index_image_id,
      :language,
      :listicles_attributes,
      :old_title_slug,
      :post_date,
      :post_now,
      :published,
      :published_at,
      :timezone,
      :title,
      :secondary_title,
      :update_title,
      :user_email,
      :user_id,
      :info_kind,
      content_tag_names: []
    )
  end

  def available_blogs
    blogs = Blog
    if %w[blog info listicle].include?(params[:search_kind])
      @search_kind = params[:search_kind]
      blogs = blogs.where(kind: @search_kind)
    else
      @search_kind = "all"
    end
    if params[:search_tags].present?
      @tags = Array(params[:search_tags]).flatten.map { |i| ContentTag.friendly_find(i) }.compact.uniq
      blogs = blogs.with_tag_ids(@tags.pluck(:id))
    end
    blogs = blogs.published if sort_column == "published_at"
    @time_range_column = (sort_column == "updated_at") ? "updated_at" : "created_at"
    blogs.where(@time_range_column => @time_range)
  end

  def set_dignified_name
    @dignified_name = "short form creative non-fiction"
    @dignified_name = "collection of vignettes" if @blog&.is_listicle
  end

  def find_blog
    @blog = Blog.friendly_find(params[:id])
  end
end
