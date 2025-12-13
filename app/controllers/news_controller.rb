class NewsController < ApplicationController
  def index
    @blogs = matching_blogs
    @blogs_count ||= @blogs.count
    @page_updated_at = matching_blogs.maximum(:updated_at)
    @show_discuss = Binxtils::InputNormalizer.boolean(ENV["SHOW_DISCOURSE"])
    redirect_to news_index_url(format: "atom") if request.format == "xml"
  end

  def show
    @blog = Blog.friendly_find(params[:id])

    unless @blog
      raise ActionController::RoutingError.new("Not Found")
    end

    if @blog.info?
      redirect_to(info_path(@blog.to_param)) && return
    end

    if @blog.is_listicle
      @page = params[:page].to_i
      @page = 1 unless @page > 0
      @list_item = @blog.listicles[@page - 1]
      @next_item = true unless @page >= @blog.listicles.count
      @prev_item = true unless @page == 1
    end
    @related_blogs = @blog.related_blogs
  end

  private

  def matching_blogs
    blogs = Blog.published.blog.in_language(params[:language])
    if params[:search_tags].present?
      @search_tags = ContentTag.matching(params[:search_tags])
      blogs = blogs.with_tag_ids(@search_tags.pluck(:id))
      @blogs_count = blogs.count.keys.count
    end
    blogs
  end
end
