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

end
