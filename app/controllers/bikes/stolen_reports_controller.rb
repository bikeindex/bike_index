module Bikes
  class StolenReportsController < Bikes::BaseController
    before_action :redirect_unless_reportable, only: %i[new create]
    before_action :find_stolen_record, only: %i[edit update show]

    def new
      @page_title = translation(:report_stolen, bike_type: @bike.type)
      render_wizard(StolenRecord.new(bike: @bike, phone: @bike.phone, country_id: default_country_id))
    end

    def edit
      @page_title = translation(:edit_report, bike_type: @bike.type)
      render_wizard(@stolen_record, step: params[:step].presence || "review")
    end

    def create
      save_report(StolenRecord.new(bike: @bike, country_id: default_country_id))
    end

    def update
      save_report(@stolen_record)
    end

    def show
      @page_title = translation(:next_steps, bike_type: @bike.type)
      render Pages::Bikes::StolenReport::NextSteps::Component.new(bike: @bike, stolen_record: @stolen_record)
    end

    # The Bike Book models the photo step's search finds, in its turbo frame
    def stock_photos
      results = Integrations::Bikebook::Catalog.stock_photos(manufacturer: params[:manufacturer],
        model: params[:model], year: params[:year])
      render Pages::Bikes::StolenReport::StockPhotos::Component.new(results:, searched: params[:manufacturer].present?,
        selected_url: params[:selected_url]), layout: false
    end

    # A photo from the photo step, stored on the bike as soon as it's picked
    def photos
      if request.content_length.to_i > PublicImageUploader::MAX_FILE_SIZE
        max_size = ActiveSupport::NumberHelper.number_to_human_size(PublicImageUploader::MAX_FILE_SIZE)
        return render(json: {error: translation(:image_too_large, size: max_size)}, status: 413)
      end

      public_image = @bike.public_images.build(file: params[:photo])
      return render(json: {html: render_to_string(Pages::Bikes::StolenReport::Photo::Component.new(public_image:), layout: false)}) if public_image.save

      render json: {error: public_image.errors.full_messages.to_sentence}, status: :unprocessable_entity
    end

    private

    def report_params
      params.fetch(:stolen_record, {}).permit(*BikeServices::StolenReport::PERMITTED_PARAMS)
    end

    def save_report(stolen_record)
      if BikeServices::StolenReport.save(bike: @bike, user: current_user, params: report_params)
        flash[:success] = translation(:report_saved, bike_type: @bike.type) if stolen_record.persisted?
        return redirect_to(bike_stolen_report_path(@bike))
      end

      # Not saved - the re-render shows what they entered
      stolen_record.assign_attributes(report_params.slice(*BikeServices::StolenReport::RECORD_ATTRIBUTES))
      missing = BikeServices::StolenReport.missing(report_params)
      render_wizard(stolen_record, step: BikeServices::StolenReport::REQUIRED[missing.first], missing:,
        submitted: report_params, status: :unprocessable_entity)
    end

    def render_wizard(stolen_record, step: params[:step], missing: [], submitted: {}, status: :ok)
      render Pages::Bikes::StolenReport::Wizard::Component.new(bike: @bike, stolen_record:,
        step: BikeServices::StolenReport.step(step), missing:, submitted:), status:
    end

    def default_country_id
      @bike.address_record&.country_id || current_user.address_record&.country_id || Country.united_states_id
    end

    def redirect_unless_reportable
      return redirect_to(edit_bike_stolen_report_path(@bike)) if @bike.status_stolen?

      redirect_to(bike_path(@bike)) if @bike.status_stolen_or_impounded? || @bike.version?
    end

    def find_stolen_record
      @stolen_record = @bike.current_stolen_record
      redirect_to(new_bike_stolen_report_path(@bike)) if @stolen_record.blank?
    end
  end
end
