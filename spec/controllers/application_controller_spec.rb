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

  it "uses the locale sent from the parameters if it is specified" do
    I18n.available_locales = [:en, :de]
    get :index, locale: :de
    I18n.locale.should == :de
  end

  it "ignores the locale sent from the parameters if it is not valid" do
    get :index, locale: :de
    I18n.locale.should == :en
  end

  it "sets the locale parameter if it is different from the default locale" do
    I18n.default_locale = :en
    I18n.locale = :de
    get :index
    @request.env["QUERY_STRING"].should == "locale=de"
  end

  it "does not set the locale if the locale is not different from the default" do
    I18n.locale = I18n.default_locale
    get :index
    @request.env["QUERY_STRING"].should be_blank
  end

  def set_preferred_language_header(language)
    @request.env['HTTP_ACCEPT_LANGUAGE'] = language
  end
end
