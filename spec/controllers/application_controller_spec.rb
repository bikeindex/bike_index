require 'spec_helper'

describe ApplicationController do
  controller do
    def index
      render nothing: true
    end
  end

  before do
    @available_locales = I18n.available_locales
  end

  after do
    I18n.available_locales = @available_locales
  end

  it "sets the locale based on the user's browser setting" do
    I18n.available_locales = [:en, :de]
    set_preferred_language_header "de"
    get :index
    I18n.locale.should == :de
  end

  it "ignores languages that are not available" do
    set_preferred_language_header "blah"
    get :index
    I18n.locale.should == :en
  end

  def set_preferred_language_header(language)
    @request.env['HTTP_ACCEPT_LANGUAGE'] = language
  end
end
