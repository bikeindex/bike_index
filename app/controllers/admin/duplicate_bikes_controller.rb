module Admin
  class DuplicateBikesController < Admin::BaseController
    include Binxtils::SortableTable
    include Admin::TokenAccessible

    around_action :set_reading_role, only: %i[index show]

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
      bike_ids = nil
      if params[:id] == "serial"
        reference = Bike.unscoped.find(params[:reference_bike_id])
        return head :bad_request if reference.manufacturer_id.nil? || reference.serial_normalized_no_space.to_s.length < 6

        bikes = BikeServices::DuplicateReviewFinder.serial_bikes(reference)
      elsif params[:id] == "compare"
        bike_ids = Array(params[:bike_ids]).flat_map { |value| value.to_s.split(",") }
          .filter_map { |value| Integer(value.strip, exception: false) }.select(&:positive?).uniq
        return head :bad_request unless bike_ids.size.between?(2, 50)

        bikes = Bike.unscoped.where(id: bike_ids)
      else
        @duplicate_group = DuplicateBikeGroup.find(params[:id])
        bikes = Bike.unscoped.where(id: @duplicate_group.normalized_serial_segments.select(:bike_id))
      end

      # Summaries cover every record, so the whole group loads; the largest whole-serial group is a few hundred
      all_bikes = bikes.includes(:manufacturer, :primary_frame_color, :current_ownership, :creation_organization,
        :marketplace_listings, ownerships: :organization).order(:created_at, :id).to_a
      raise ActiveRecord::RecordNotFound if bike_ids && all_bikes.size != bike_ids.size
      @bikes_count = all_bikes.size
      @reference_bike = if params[:reference_bike_id].present?
        all_bikes.find { it.id == params[:reference_bike_id].to_i } || raise(ActiveRecord::RecordNotFound)
      else
        all_bikes.min_by(&:id)
      end
      @review = DuplicateBikeReview.new(bikes: all_bikes, reference_bike: @reference_bike,
        manufacturer_names: BikeServices::DuplicateReviewCues.cached_manufacturer_name_serials)
      @contact_group = @review.contact_groups.find { it.number == params[:search_contact].to_i }
      @per_page = permitted_per_page(default: 25)
      listed_bikes = @contact_group&.bikes || all_bikes
      listed_bikes = listed_bikes.reverse if sort_direction == "desc"
      @pagy, @bikes = pagy(:offset, listed_bikes, limit: @per_page, page: permitted_page)
      @test_bike_ids = BikeServices::DuplicateReviewFinder.test_bike_ids(all_bikes.map(&:id)).to_set
      @stolen_record_counts = StolenRecord.unscoped.where(bike_id: all_bikes.map(&:id)).group(:bike_id).count
      @serial_stolen = BikeServices::DuplicateReviewFinder.stolen_serials?(all_bikes.map(&:serial_normalized_no_space).uniq)
      @checks = @review.readiness_checks(serial_stolen: @serial_stolen, test_count: @test_bike_ids.size)
      @readiness = @review.readiness(@checks)

      respond_to do |format|
        format.html do
          # Only the HTML shows these, and only for the listed records
          ActiveRecord::Associations::Preloader.new(records: @bikes, associations: %i[bike_organizations bike_stickers public_images]).call
          account_ids = all_bikes.flat_map { |bike| bike.ownerships.map(&:user_id) }.compact.uniq
          @account_emails = User.unscoped.where(id: account_ids).pluck(:id, :email).to_h
        end
        format.json { render json: review_json }
      end
    end

    private

    def dashboard
      @per_page = permitted_per_page(default: 25)
      database = ActiveRecord::Base.connection_db_config.database
      cache = BikeServices::DuplicateReviewFinder.cache
      @group_snapshot = cache.read(BikeServices::DuplicateReviewFinder.cache_key(database))
      unless @group_snapshot
        prepare_dashboard(database, cache)
        html_status, json_status, label = @preparation_failed ? [:service_unavailable, :service_unavailable, "failed"] : [:ok, :accepted, "preparing"]
        return respond_to do |format|
          format.html { render :preparing, status: html_status }
          format.json { render json: {status: label}, status: json_status }
        end
      end
      summary = @group_snapshot[:groups].group_by { it["kind"] }
      @queues = BikeServices::DuplicateReviewFinder::KINDS.to_h do |kind, label|
        kind_groups = summary.fetch(kind, [])
        [kind, {label:, groups: kind_groups.size, records: kind_groups.sum { it["record_count"] }}]
      end
      @kind = params[:search_kind].presence_in(BikeServices::DuplicateReviewFinder::KINDS.keys) || "handoff_priority"
      groups = summary.fetch(@kind, [])
      if params[:search_organization_id].present?
        @organization = Organization.unscoped.find(params[:search_organization_id])
        groups = groups.select { it["organization_ids"]&.include?(@organization.id) }
      end
      if params[:search_bike_id].present?
        bike_id = Integer(params[:search_bike_id], exception: false)
        groups = groups.select { it["bike_ids"].include?(bike_id) }
      end
      @queue_groups_count = groups.size
      @cue = params[:search_cue].presence_in(BikeServices::DuplicateReviewCues::FILTERS.keys)
      groups, @cue_counts = BikeServices::DuplicateReviewCues.filter(groups, @cue)
      # The cache is already largest first; other sorts keep the lowest bike ID first on ties
      unless sort_column == default_column && sort_direction == default_direction
        sign = (sort_direction == "desc") ? -1 : 1
        groups = groups.sort_by { [sign * it[sort_column].to_f, it["reference_id"]] }
      end
      @groups_count = groups.size
      @registrations_count = groups.sum { it["record_count"] }
      @pagy, @groups = pagy(:offset, groups, limit: @per_page, page: permitted_page)
      respond_to do |format|
        format.html do
          @representatives = Bike.unscoped.where(id: @groups.map { it["reference_id"] })
            .includes(:manufacturer, :ownerships).index_by(&:id)
          @organizations = Organization.unscoped.where(id: @groups.flat_map { it["organization_ids"] || [] }).index_by(&:id)
          render :dashboard
        end
        format.json { render json: dashboard_json }
      end
    end

    # Token JSON carries record IDs and review evidence. Cues and contact groups serialize without
    # contact emails themselves; the rest is picked field by field
    def dashboard_json
      {generated_at: @group_snapshot[:generated_at], kind: @kind, cue: @cue, sort: sort_column, direction: sort_direction,
       queues: @queues, cue_counts: @cue_counts, registrations_count: @registrations_count,
       page: @pagy.page, per_page: @per_page, total_count: @pagy.count, groups: @groups.map { group_json(it) }}
    end

    def group_json(group)
      group.slice("reference_id", "bike_ids", "manufacturer_id", "serial", "record_count", "first_at", "last_at", "kind",
        "serial_stolen", "test_count", "email_count", "account_count", "organization_ids", "handoff_priority")
        .merge("cues" => BikeServices::DuplicateReviewCues.group_cues(group))
    end

    def review_json
      {reference_bike_id: @reference_bike.id, records_count: @bikes_count, serial_stolen: @serial_stolen,
       not_a_serial: @review.not_a_serial, readiness: @readiness, checks: @checks,
       cues: @review.cues(test_count: @test_bike_ids.size),
       shared_fields: @review.shared_fields.to_h { [it, @review.field_value(@reference_bike, it)] },
       differing_fields: @review.differing_fields.to_h { [it, @review.field_distribution(it)] },
       contact_groups: @review.contact_groups, test_bike_ids: @test_bike_ids.to_a, contact_group: @contact_group&.number,
       direction: sort_direction, page: @pagy.page, per_page: @per_page, total_count: @pagy.count,
       records: @bikes.map { record_json(it) }}
    end

    def record_json(bike)
      initial = @review.initial_ownership(bike)
      bike.as_json(only: %w[id created_at manufacturer_id frame_model year serial_number status])
        .merge("serial_normalized" => bike.serial_normalized_no_space, "source" => @review.source(bike),
          "initial_organization_id" => @review.organization(bike)&.id, "initial_account_id" => initial&.user_id,
          "current_account_id" => bike.current_ownership&.user_id, "claim_status" => @review.claim_status(initial),
          "transferred" => @review.transferred?(bike), "contact_group" => @review.contact_group(bike)&.number,
          "differences" => @review.differences(bike), "test" => @test_bike_ids.include?(bike.id),
          "stolen_record_count" => @stolen_record_counts[bike.id] || 0)
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

    # Comparison records sort by registration; dashboard groups (cached hashes) by record count,
    # first or latest registration. The segments view has a fixed order
    def sortable_columns
      (action_name == "show") ? %w[created_at] : %w[record_count first_at last_at]
    end

    # Comparison records read oldest first, like the registration history
    def default_direction = (action_name == "show") ? "asc" : "desc"

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
          Arel.sql("COUNT(DISTINCT bikes.id) FILTER (WHERE #{BikeServices::DuplicateReviewFinder.stolen_history_sql("bikes")})"))
        .to_h { |id, count, serials, manufacturers, stolen| [id, {count:, serials:, manufacturers:, stolen:}] }
    end
  end
end
