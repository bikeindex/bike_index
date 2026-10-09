# frozen_string_literal: true

module BikeServices
  module DuplicateReviewFinder
    extend Functionable

    LARGE_GROUP_MINIMUM = 10
    KINDS = {
      "stolen_history" => "Stolen history — preserve separately",
      "internal_test" => "Internal test markers",
      "mixed_test" => "Test and other records together",
      "large_group" => "Large groups — validate the serial",
      "pos_repeat" => "Repeated unclaimed shop registrations",
      "handoff_priority" => "Shop followed by customer — strongest evidence",
      "shop_customer" => "Shop followed by customer — review",
      "same_identity" => "Same contact or account — review",
      "unresolved" => "Different or missing identity",
      "not_a_serial" => "Placeholder or part-number serial — not a duplicate match"
    }.freeze
    # Queues a future merge invitation could draw from; the rest need separate review
    SAME_OWNER_KINDS = %w[handoff_priority shop_customer same_identity].freeze

    def cache
      return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      directory = Rails.root.join("tmp", "duplicate_review_cache")
      FileUtils.mkdir_p(directory, mode: 0o700)
      File.chmod(0o700, directory)
      ActiveSupport::Cache::FileStore.new(directory)
    end

    def with_preparation_lock(cache)
      return yield unless cache.is_a?(ActiveSupport::Cache::FileStore)

      File.open(File.join(cache.cache_path, "duplicate_review_preparation.lock"), File::RDWR | File::CREAT, 0o600) do |file|
        file.flock(File::LOCK_EX)
        yield
      end
    end

    def cache_key(database) = ["duplicate_review_groups_v7", database]

    def preparation_key(database) = ["duplicate_review_groups_preparing_v7", database]

    def groups
      manufacturer_names = DuplicateReviewCues.manufacturer_name_serials
      ActiveRecord::Base.connection.select_all(query).to_a.map do |group|
        group["manufacturer_name_serial"] = manufacturer_names[group["serial"]]
        group.merge("kind" => kind(group),
          "bike_ids" => JSON.parse(group["bike_ids"]),
          "organization_ids" => JSON.parse(group["organization_ids"] || "[]"),
          "first_at" => group["first_at"].in_time_zone,
          "last_at" => group["last_at"].in_time_zone)
      end
    end

    # A placeholder or part-number serial isn't evidence of anything, so it outranks every other queue.
    # The stolen badge still shows in that queue
    def kind(group)
      return "not_a_serial" if DuplicateReviewCues.not_a_serial(group["serial"], manufacturer_names: DuplicateReviewCues.group_manufacturer_names(group))
      return "stolen_history" if group["serial_stolen"]
      return "internal_test" if group["test_count"] == group["record_count"]
      return "mixed_test" if group["test_count"].positive?
      return "large_group" if group["record_count"] >= LARGE_GROUP_MINIMUM
      return "handoff_priority" if group["handoff_priority"]
      return "pos_repeat" if group["pos_count"] == group["record_count"] && group["ever_claimed_count"].zero? && group["transfer_count"].zero? && group["email_count"] == 1 && group["missing_email_count"].zero? && group["organization_count"] == 1 && group["missing_organization_count"].zero?
      return "shop_customer" if group["record_count"] == 2 && group["pos_count"] == 1 && group["customer_count"] == 1 && group["pos_first"]
      return "same_identity" if DuplicateReviewCues.single_contact?(group)

      "unresolved"
    end

    def serial_bikes(reference)
      Bike.unscoped.where(deleted_at: nil).where("example IS NOT TRUE AND likely_spam IS NOT TRUE")
        .where(manufacturer_id: reference.manufacturer_id, serial_normalized_no_space: reference.serial_normalized_no_space)
    end

    # Current, historical or recovered: any of them vetoes merging a whole serial
    def stolen_history_sql(table)
      "(#{table}.status = 1 OR #{table}.current_stolen_record_id IS NOT NULL" \
        " OR EXISTS (SELECT 1 FROM stolen_records WHERE stolen_records.bike_id = #{table}.id))"
    end

    def stolen_serials?(serials)
      serials = serials.reject(&:blank?)
      return false if serials.empty?

      Bike.unscoped.where(serial_normalized_no_space: serials)
        .where(stolen_history_sql("bikes")).exists?
    end

    # The same test-marker rule the queues use, for records loaded outside them
    def test_bike_ids(bike_ids)
      return [] if bike_ids.empty?

      # Not materialized, so the bike_id filter reaches each union branch's index
      sql = "WITH #{test_bikes_sql(materialized: false)} SELECT bike_id FROM test_bikes WHERE bike_id IN (?)"
      ActiveRecord::Base.connection.select_values(ActiveRecord::Base.sanitize_sql_array([sql, bike_ids]))
    end

    #
    # private below here
    #

    def test_bikes_sql(materialized: true)
      <<~SQL.strip
        admin_organizations AS MATERIALIZED (
          SELECT id FROM organizations WHERE slug = 'bikeindex' OR lower(btrim(name)) = 'bike index administrators'
        ), test_bikes AS #{"MATERIALIZED " if materialized}(
          SELECT id bike_id FROM bikes WHERE creation_organization_id IN (SELECT id FROM admin_organizations)
            OR lower(btrim(owner_email)) = 'testing@example.com'
          UNION SELECT bike_id FROM ownerships WHERE organization_id IN (SELECT id FROM admin_organizations)
            OR (is_phone IS NOT TRUE AND lower(btrim(owner_email)) = 'testing@example.com')
          UNION SELECT o.bike_id FROM ownerships o JOIN users u ON u.id = o.user_id WHERE lower(btrim(u.email)) = 'testing@example.com'
          UNION SELECT bike_id FROM bike_organizations WHERE organization_id IN (SELECT id FROM admin_organizations)
        )
      SQL
    end

    def query
      <<~SQL
        WITH #{test_bikes_sql}, live AS MATERIALIZED (
          SELECT id, manufacturer_id, serial_normalized_no_space serial, created_at, creation_organization_id,
            current_ownership_id, status, current_impound_record_id, frame_model, year, manufacturer_other,
            regexp_replace(upper(coalesce(serial_number, '')), '[^A-Z0-9]', '', 'g') simple_serial
          FROM bikes WHERE deleted_at IS NULL AND example IS NOT TRUE AND likely_spam IS NOT TRUE
            AND manufacturer_id IS NOT NULL AND length(serial_normalized_no_space) >= 6
        ), duplicate_keys AS MATERIALIZED (
          SELECT manufacturer_id, serial FROM live GROUP BY manufacturer_id, serial HAVING count(*) > 1
        ), stolen_serials AS MATERIALIZED (
          SELECT DISTINCT b.serial_normalized_no_space serial FROM bikes b
          WHERE #{stolen_history_sql("b")}
        ), registrations AS (
          SELECT b.*, o.user_id, coalesce(o.organization_id, b.creation_organization_id) organization_id,
            CASE WHEN o.is_phone IS NOT TRUE AND btrim(o.owner_email) ~ '^[^@[:space:]]+@[^@[:space:]]+$' THEN lower(btrim(o.owner_email)) END email,
            coalesce(o.pos_kind IN (2, 3), false) pos,
            coalesce(o.origin IN (0, 1, 2, 3, 7, 13, 14, 15, 16) AND coalesce(o.pos_kind, 0) NOT IN (1, 2, 3, 4, 6), false) customer,
            coalesce(o.claimed OR o.claimed_at IS NOT NULL, false) claimed,
            coalesce((o.claimed OR o.claimed_at IS NOT NULL) AND o.user_id IS NOT NULL AND o.creator_id = o.user_id
              AND o.creator_id IS DISTINCT FROM g.auto_user_id, false) self_registered,
            EXISTS (SELECT 1 FROM ownerships h WHERE h.bike_id = b.id AND (h.claimed OR h.claimed_at IS NOT NULL)) ever_claimed,
            EXISTS (SELECT 1 FROM ownerships h WHERE h.bike_id = b.id AND h.previous_ownership_id IS NOT NULL) transferred,
            EXISTS (SELECT 1 FROM marketplace_listings m WHERE m.item_type = 'Bike' AND m.item_id = b.id)
              OR EXISTS (SELECT 1 FROM marketplace_listings m JOIN bike_versions v ON m.item_type = 'BikeVersion' AND m.item_id = v.id WHERE v.bike_id = b.id) marketplace,
            coalesce(c.user_id = o.user_id AND c.is_phone IS NOT TRUE AND lower(btrim(c.owner_email)) = lower(btrim(o.owner_email)), false) current_identity_matches,
            t.bike_id IS NOT NULL test, s.serial IS NOT NULL serial_stolen
          FROM live b JOIN duplicate_keys k ON k.manufacturer_id = b.manufacturer_id AND k.serial = b.serial
          LEFT JOIN LATERAL (
            SELECT user_id, creator_id, organization_id, owner_email, is_phone, origin, pos_kind, claimed, claimed_at
            FROM ownerships WHERE bike_id = b.id
            ORDER BY (previous_ownership_id IS NULL) DESC, created_at, id LIMIT 1
          ) o ON true
          LEFT JOIN organizations g ON g.id = coalesce(o.organization_id, b.creation_organization_id)
          LEFT JOIN ownerships c ON c.id = b.current_ownership_id AND c.bike_id = b.id
          LEFT JOIN test_bikes t ON t.bike_id = b.id
          LEFT JOIN stolen_serials s ON s.serial = b.serial
        )
        SELECT manufacturer_id, serial, min(id) reference_id, jsonb_agg(id ORDER BY created_at, id) bike_ids,
          count(*)::integer record_count, count(*) FILTER (WHERE test)::integer test_count,
          count(*) FILTER (WHERE pos)::integer pos_count, count(*) FILTER (WHERE customer)::integer customer_count,
          count(*) FILTER (WHERE claimed)::integer claimed_count,
          count(*) FILTER (WHERE ever_claimed)::integer ever_claimed_count,
          count(*) FILTER (WHERE transferred)::integer transfer_count,
          count(DISTINCT email)::integer email_count, count(*) FILTER (WHERE email IS NULL)::integer missing_email_count,
          count(*) FILTER (WHERE #{DuplicateReviewCues.review_contact_sql("email")})::integer review_contact_count,
          count(DISTINCT user_id)::integer account_count, count(*) FILTER (WHERE user_id IS NULL)::integer missing_account_count,
          count(DISTINCT organization_id)::integer organization_count, count(*) FILTER (WHERE organization_id IS NULL)::integer missing_organization_count,
          jsonb_agg(DISTINCT organization_id) FILTER (WHERE organization_id IS NOT NULL) organization_ids,
          min(created_at) first_at, max(created_at) last_at,
          coalesce(min(created_at) FILTER (WHERE pos) < min(created_at) FILTER (WHERE customer), false) pos_first,
          bool_or(serial_stolen) serial_stolen,
          count(*) = 2 AND count(*) FILTER (WHERE pos) = 1 AND count(*) FILTER (WHERE customer AND self_registered) = 1
            AND min(created_at) FILTER (WHERE pos) < min(created_at) FILTER (WHERE customer)
            AND count(*) FILTER (WHERE pos AND ever_claimed) = 0
            AND count(*) FILTER (WHERE transferred OR marketplace OR NOT current_identity_matches OR current_impound_record_id IS NOT NULL OR status IS DISTINCT FROM 0) = 0
            AND count(DISTINCT email) = 1 AND count(email) = 2 AND count(DISTINCT user_id) = 1 AND count(user_id) = 2
            AND count(DISTINCT nullif(lower(btrim(frame_model)), '')) <= 1 AND count(DISTINCT year) <= 1
            AND count(DISTINCT nullif(lower(btrim(manufacturer_other)), '')) <= 1
            AND count(DISTINCT simple_serial) = 1
            AND EXISTS (SELECT 1 FROM manufacturers m WHERE m.id = manufacturer_id AND nullif(btrim(m.name), '') IS NOT NULL AND m.name <> 'Other') handoff_priority
        FROM registrations GROUP BY manufacturer_id, serial
        ORDER BY count(*) DESC, min(id)
      SQL
    end

    conceal :query, :test_bikes_sql
  end
end
