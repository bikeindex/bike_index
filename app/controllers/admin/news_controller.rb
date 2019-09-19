class Admin::NewsController < Admin::BaseController
  before_filter :find_blog, only: [:show, :edit, :update, :destroy]
  before_filter :set_dignified_name
  before_filter :normalize_params

  def index
    @blogs = Blog.order("created_at asc")
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
  end

  def update
    if @blog.update(permitted_parameters)
      @blog.reload

      if @blog.listicles.present?
        @blog.listicles.pluck(:id).each { |id| ListicleImageSizeWorker.perform_in(1.minutes, id) }
      end

      flash[:success] = "Blog saved!"
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
      is_listicle: false,
    })
    if @blog.save
      flash[:success] = "Blog created!"
      redirect_to edit_admin_news_url(@blog)
    else
      flash[:error] = "Blog error! #{@blog.errors.full_messages.to_sentence}"
      redirect_to new_admin_news_path
    end
  end

  def destroy
    @blog.destroy
    redirect_to admin_news_index_url
  end

  protected

  def permitted_parameters
    params.require(:blog).permit(
      :body,
      :description_abbr,
      :index_image,
      :index_image_id,
      :is_listicle,
      :language,
      :listicles_attributes,
      :old_title_slug,
      :post_date,
      :post_now,
      :published,
      :published_at,
      :tags,
      :timezone,
      :title,
      :update_title,
      :user_email,
      :user_id,
    )
  end

  def normalize_params
    language = params.dig(:blog, :language)
    params[:blog][:language] = language.to_i if language.present?
  end

  def set_dignified_name
    @dignified_name = "short form creative non-fiction"
    @dignified_name = "collection of vignettes" if @blog && @blog.is_listicle
  end

  def find_blog
    @blog = Blog.friendly_find(params[:id])
  end
end
