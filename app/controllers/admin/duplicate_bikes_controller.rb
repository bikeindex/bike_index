module Admin
  class DuplicateBikesController < Admin::BaseController
    include Binxtils::SortableTable

    around_action :set_reading_role, only: %i[index show]
    before_action :set_review_read_only, only: %i[show update]

    def index
      return dashboard unless params[:search_view] == "segments"

      @per_page = permitted_per_page(default: 25)
      groups = matching_groups.order(added_bike_at: :desc, id: :desc)
      @duplicate_groups_count = groups.count
      @pagy, @duplicate_groups = pagy(:countish, groups, limit: @per_page, page: permitted_page)
      group_ids = @duplicate_groups.map(&:id)
      @segments = NormalizedSerialSegment.where(duplicate_bike_group_id: group_ids).group(:duplicate_bike_group_id).minimum(:segment)
      @group_statistics = group_statistics(group_ids)
    end

    def show
      if params[:id] == "serial"
        reference = Bike.unscoped.find(params[:reference_bike_id])
        return head :bad_request if reference.manufacturer_id.nil? || reference.serial_normalized_no_space.to_s.length < 6

        bikes = BikeServices::DuplicateReviewFinder.serial_bikes(reference)
      elsif params[:id] == "compare"
        bike_ids = Array(params[:bike_ids]).flat_map { |value| value.to_s.split(",") }
          .filter_map { |value| Integer(value.strip, exception: false) }.select(&:positive?).uniq
        return head :bad_request unless bike_ids.size.between?(2, 50)

        bikes = Bike.unscoped.where(id: bike_ids)
        raise ActiveRecord::RecordNotFound unless bikes.count == bike_ids.size
      else
        @duplicate_group = DuplicateBikeGroup.find(params[:id])
        bikes = Bike.unscoped.where(id: @duplicate_group.normalized_serial_segments.select(:bike_id))
      end

      @bikes_count = bikes.count
      @per_page = permitted_per_page(default: 25)
      @pagy, @bikes = pagy(:countish, bikes.order(:id), limit: @per_page, page: permitted_page)
      @bikes = @bikes.includes(:manufacturer, :current_ownership, :creation_organization,
        :bike_organizations, :bike_stickers, :public_images, :marketplace_listings, ownerships: :organization).to_a
      @reference_bike = if params[:reference_bike_id].present?
        bikes.includes(:ownerships, :current_ownership).find(params[:reference_bike_id])
      else
        bikes.includes(:ownerships, :current_ownership).order(:id).first
      end
      @review = DuplicateBikeReview.new(bikes: @bikes, reference_bike: @reference_bike)
      @stolen_record_counts = StolenRecord.unscoped.where(bike_id: @bikes.map(&:id)).group(:bike_id).count
      @serial_stolen = BikeServices::DuplicateReviewFinder.stolen_serials?(bikes.distinct.pluck(:serial_normalized_no_space))
      account_ids = @bikes.flat_map { |bike| bike.ownerships.map(&:user_id) }.compact.uniq
      @account_emails = User.unscoped.where(id: account_ids).pluck(:id, :email).to_h
    end

    def update
      head :method_not_allowed
    end

    private

    def dashboard
      @per_page = permitted_per_page(default: 25)
      database = ActiveRecord::Base.connection_db_config.database
      cache = BikeServices::DuplicateReviewFinder.cache
      @group_snapshot = cache.read(BikeServices::DuplicateReviewFinder.cache_key(database))
      unless @group_snapshot
        prepare_dashboard(database, cache)
        return render :preparing, status: @preparation_failed ? :service_unavailable : :ok
      end
      @summary = @group_snapshot[:groups].group_by { it["kind"] }
      @kind = params[:search_kind].presence_in(BikeServices::DuplicateReviewFinder::KINDS.keys) || "handoff_priority"
      groups = @summary.fetch(@kind, [])
      if params[:search_organization_id].present?
        @organization = Organization.unscoped.find(params[:search_organization_id])
        groups = groups.select { it["organization_ids"]&.include?(@organization.id) }
      end
      if params[:search_bike_id].present?
        bike_id = Integer(params[:search_bike_id], exception: false)
        groups = groups.select { it["bike_ids"].include?(bike_id) }
      end
      @groups_count = groups.size
      @registrations_count = groups.sum { it["record_count"] }
      @pagy, @groups = pagy(:offset, groups, limit: @per_page, page: permitted_page)
      @representatives = Bike.unscoped.where(id: @groups.map { it["reference_id"] })
        .includes(:manufacturer, :creation_organization, :ownerships).index_by(&:id)
      @organizations = Organization.unscoped.where(id: @groups.flat_map { it["organization_ids"] || [] }).index_by(&:id)
      render :dashboard
    end

    def prepare_dashboard(database, cache)
      key = BikeServices::DuplicateReviewFinder.preparation_key(database)
      token = SecureRandom.uuid
      acquired = BikeServices::DuplicateReviewFinder.with_preparation_lock(cache) do
        cache.read(key)
        cache.write(key, token, unless_exist: true, expires_in: 30.minutes)
      end
      unless acquired
        @preparation_failed = cache.read(key).nil?
        return
      end

      begin
        BikeJobs::PrepareDuplicateReviewJob.perform_async(database, token)
      rescue RedisClient::Error
        @preparation_failed = true
        cache.delete(key) if cache.read(key) == token
      end
    end

    def sortable_columns
      %w[id created_at added_bike_at]
    end

    def set_review_read_only
      @review_read_only = true
    end

    def matching_groups
      groups = case params[:search_ignored]
      when "all" then DuplicateBikeGroup.all
      when "true" then DuplicateBikeGroup.where(ignore: true)
      else DuplicateBikeGroup.unignored
      end
      if params[:search_bike_id].present?
        groups = groups.where(id: NormalizedSerialSegment.where(bike_id: params[:search_bike_id]).select(:duplicate_bike_group_id))
      end
      groups
    end

    def group_statistics(group_ids)
      NormalizedSerialSegment.where(duplicate_bike_group_id: group_ids)
        .joins("INNER JOIN bikes ON bikes.id = normalized_serial_segments.bike_id")
        .group(:duplicate_bike_group_id)
        .pluck(:duplicate_bike_group_id, Arel.sql("COUNT(DISTINCT bikes.id)"),
          Arel.sql("COUNT(DISTINCT NULLIF(bikes.serial_normalized_no_space, ''))"),
          Arel.sql("COUNT(DISTINCT bikes.manufacturer_id)"),
          Arel.sql("COUNT(DISTINCT bikes.id) FILTER (WHERE bikes.status = 1 OR bikes.current_stolen_record_id IS NOT NULL OR EXISTS (SELECT 1 FROM stolen_records WHERE stolen_records.bike_id = bikes.id))"))
        .to_h { |id, count, serials, manufacturers, stolen| [id, {count:, serials:, manufacturers:, stolen:}] }
    end
  end
end
