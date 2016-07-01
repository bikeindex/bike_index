class BlogsController < ApplicationController

  def index
    redirect_to news_index_url
  end
  
  def show
    redirect_to news_url
  end
end
