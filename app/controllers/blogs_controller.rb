class BlogsController < ApplicationController
  layout 'content'
  before_filter :set_blogs_active_section

  def show
    @blog = Blog.find_by_title_slug(params[:id])
    @title = @blog.title
  end

  def index
    @title = "Blog"
    @blogs = Blog.where(published: true).order("post_date desc")
  end

  def set_blogs_active_section
    @active_section = "about"
  end

end