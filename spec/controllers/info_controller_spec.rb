require 'spec_helper'

describe InfoController do

  describe :about do
    before do
      get :about
    end
    it { should respond_with(:success) }
    it { should render_template(:about) }
  end

  describe :protect_your_bike do
    before do
      get :protect_your_bike
    end
    it { should respond_with(:success) }
    it { should render_template(:protect_your_bike) }
  end

  describe :where do
    before do
      FactoryGirl.create(:country, iso: "US")
      get :where
    end
    it { should respond_with(:success) }
    it { should render_template(:where)}
  end

  describe :roadmap do
    before do
      get :roadmap
    end
    it { should respond_with(:success) }
    it { should render_template(:roadmap)}
  end

  describe :security do
    before do
      get :security
    end
    it { should respond_with(:success) }
    it { should render_template(:security)}
  end

  describe :serials do
    context 'for english speakers' do
      before { get :serials }
      it { should respond_with(:success) }
      it { should render_template(:serials)}
    end

    context 'for the spanish speakers' do
      render_views

      before do
        I18n.default_locale = :es
        get :serials
      end

      it 'renders the spanish localized template' do
        expect(response.body).to match /Holla/im
      end
    end
  end

  describe :stolen_bikes do
    before do
      get :stolen_bikes
    end
    it { should respond_with(:success) }
    it { should render_template(:stolen_bikes)}
  end

  describe :privacy do
    before do
      get :privacy
    end
    it { should respond_with(:success) }
    it { should render_template(:privacy)}
  end

  describe :terms do
    before do
      get :terms
    end
    it { should respond_with(:success) }
    it { should render_template(:terms)}
  end

  describe :vendor_terms do
    before do
      get :vendor_terms
    end
    it { should respond_with(:success) }
    it { should render_template(:vendor_terms)}
  end

  describe :resources do
    before do
      get :resources
    end
    it { should respond_with(:success) }
    it { should render_template(:resources)}
  end

  describe :spokecard do
    before do
      get :spokecard
    end
    it { should respond_with(:success) }
    it { should render_template(:spokecard)}
  end

  context "locale scoped routes" do
    let(:paths) { [:stolen_bikes, :protect_your_bike, :privacy, :terms, :serials,
                   :about, :where, :roadmap, :security, :vendor_terms, :resources, :spokecard] }
    let(:locales) { [:en, :de] }

    before do
      @available_locales = I18n.available_locales
      I18n.available_locales = locales
      Rails.application.reload_routes!
    end

    after do
      I18n.available_locales = @available_locales
      Rails.application.reload_routes!
    end

    it "should route to the correct locale if the locale exists" do
      paths.each do |path|
        { get: path }.should be_routable # should allow a route without a locale
        locales.each do |locale|
          { get: "#{locale}/#{path}" }.should be_routable # should allow a valid locale to be specified
        end
      end
    end

    it "should not route if the locale is not supported" do
      paths.each do |path|
        { get: "blah/#{path}" }.should_not be_routable
      end
    end
  end

end
