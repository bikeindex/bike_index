module Admin
  class DuplicateBikesController < Admin::BaseController
    include Binxtils::SortableTable

    LINK_PARAM_KEYS = %w[sort direction page per_page reference_bike_id bike_ids].freeze
    # A review loads every record in the group. A segment shared by thousands of bikes ("000000") is
    # sent back to the list rather than loaded; the largest whole-serial group is a few hundred
    MAX_REVIEW_RECORDS = 500

    around_action :set_reading_role, only: %i[index show]
    helper_method :link_params

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

        bikes = BikeDuplicatesServices::Finder.serial_bikes(reference)
      elsif params[:id] == "compare"
        bike_ids = Array(params[:bike_ids]).flat_map { |value| value.to_s.split(",") }
          .filter_map { |value| Integer(value.strip, exception: false) }.select(&:positive?).uniq
        return head :bad_request unless bike_ids.size.between?(2, 50)

        bikes = Bike.unscoped.where(id: bike_ids)
      else
        @duplicate_group = DuplicateBikeGroup.find(params[:id])
        # Admins review every record in the group, including hidden and deleted ones
        bikes = @duplicate_group.bikes.unscope(where: %i[example user_hidden deleted_at likely_spam])
      end

      records_count = bikes.count
      if records_count > MAX_REVIEW_RECORDS
        flash[:error] = "#{records_count} records are too many to review together"
        return redirect_to admin_duplicate_bikes_path(search_view: @duplicate_group && "segments")
      end

      # Summaries cover every record, so the whole group loads
      all_bikes = bikes.default_includes.includes(:manufacturer, :creation_organization, :marketplace_listings,
        :bike_organizations, :bike_stickers, :public_images, ownerships: :organization).reorder(:created_at, :id).to_a
      raise ActiveRecord::RecordNotFound if all_bikes.empty? || bike_ids && all_bikes.size != bike_ids.size
      @bikes_count = all_bikes.size
      @reference_bike = if params[:reference_bike_id].present?
        all_bikes.find { it.id == params[:reference_bike_id].to_i } || raise(ActiveRecord::RecordNotFound)
      else
        all_bikes.min_by(&:id)
      end
      @review = BikeDuplicatesServices::Review.new(bikes: all_bikes, reference_bike: @reference_bike)
      @contact_group = @review.contact_groups.find { it.number == params[:search_contact].to_i }
      @per_page = permitted_per_page(default: 25)
      listed_bikes = @contact_group&.bikes || all_bikes
      listed_bikes = listed_bikes.reverse if sort_direction == "desc"
      @pagy, @bikes = pagy(:offset, listed_bikes, limit: @per_page, page: permitted_page)
    end

    private

    # url_for reads host, protocol and the like from its hash, so links only carry the page's own params
    def link_params
      request.query_parameters.select { |key, _| key.start_with?("search_") || LINK_PARAM_KEYS.include?(key) }
    end

    def dashboard
      @per_page = permitted_per_page(default: 25)
      @group_snapshot = BikeDuplicatesServices::Finder.fetch_group_snapshot
      return render :preparing unless @group_snapshot

      @summary = @group_snapshot[:groups].group_by { it["kind"] }
      @kind = params[:search_kind].presence_in(BikeDuplicatesServices::Finder::KINDS.keys) || "handoff_priority"
      groups = @summary.fetch(@kind, [])
      if params[:search_organization_id].present?
        @organization = Organization.unscoped.find(params[:search_organization_id])
        groups = groups.select { it["organization_ids"]&.include?(@organization.id) }
      end
      if params[:search_bike_id].present?
        bike_id = Integer(params[:search_bike_id], exception: false)
        groups = groups.select { it["bike_ids"].include?(bike_id) }
      end
      @queue_groups_count = groups.size
      @cue = params[:search_cue].presence_in(BikeDuplicatesServices::Cues::FILTERS.keys)
      groups, @cue_counts = BikeDuplicatesServices::Cues.filter(groups, @cue)
      # The snapshot is already largest first; other sorts keep the lowest bike ID first on ties
      unless sort_column == default_column && sort_direction == default_direction
        sign = (sort_direction == "desc") ? -1 : 1
        groups = groups.sort_by { [sign * it[sort_column].to_f, it["reference_id"]] }
      end
      @groups_count = groups.size
      @registrations_count = groups.sum { it["record_count"] }
      @pagy, @groups = pagy(:offset, groups, limit: @per_page, page: permitted_page)
      # The snapshot can be hours old, so the listed groups' stolen veto is read live. Only the
      # listed groups get their cues and times built
      stolen_serials = BikeDuplicatesServices::Finder.stolen_serials(@groups.map { it["serial"] })
      @groups = @groups.map do |group|
        group.merge("serial_stolen" => stolen_serials.include?(group["serial"]), "cues" => BikeDuplicatesServices::Cues.group_cues(group),
          "first_at" => Time.zone.at(group["first_at"]), "last_at" => Time.zone.at(group["last_at"]))
      end
      @representatives = Bike.unscoped.where(id: @groups.map { it["reference_id"] })
        .includes(:manufacturer, :ownerships).index_by(&:id)
      @organizations = Organization.unscoped.where(id: @groups.flat_map { it["organization_ids"] || [] }).index_by(&:id)
      render :dashboard
    end

    # Comparison records sort by registration; dashboard groups (snapshot hashes) by record count,
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
          Arel.sql("COUNT(DISTINCT bikes.id) FILTER (WHERE #{BikeDuplicatesServices::Finder.stolen_history_sql("bikes")})"))
        .to_h { |id, count, serials, manufacturers, stolen| [id, {count:, serials:, manufacturers:, stolen:}] }
    end
  end
end
