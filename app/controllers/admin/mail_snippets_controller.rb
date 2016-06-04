class Admin::MailSnippetsController < Admin::BaseController
  before_filter :find_snippet, except: [:index, :new, :create]
  
  def index
    @mail_snippets = MailSnippet.all
  end

  def show
    redirect_to edit_admin_mail_snippet_url(@mail_snippet)
  end

  def edit
    
  end

  def update
    if @mail_snippet.update_attributes(params[:mail_snippet])
      flash[:success] = 'Snippet Saved!'
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :edit
    end
  end

  def new
    @mail_snippet = MailSnippet.new
  end

  def create
    @mail_snippet = MailSnippet.create(params[:mail_snippet])
    if @mail_snippet.save
      flash[:success] = 'Snippet Created!'
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :new
    end
  end


  protected

  def find_snippet
    @mail_snippet = MailSnippet.find(params[:id])
  end

end
