module Admin
  class CycleTypesController < Admin::BaseController
    def index
      render Pages::Admin::CycleTypeDrawings::Component.new(cycle_types: CycleType.all, manifest_url: Integrations::Bikebook::Catalog::MANIFEST_URL)
    end
  end
end
