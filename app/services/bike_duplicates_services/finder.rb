# frozen_string_literal: true

module BikeDuplicatesServices
  module Finder
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
    # The integrations whose registrations are a shop's sale
    POS_KINDS = %w[lightspeed_pos ascend_pos].freeze

    SNAPSHOT_KEY = "duplicate_review_group_snapshot"
    PREPARING_KEY = "duplicate_review_group_snapshot_preparing"
    SNAPSHOT_TTL = 1.hour
    # Longer than the query takes; if the job dies, the next visit after this enqueues another
    PREPARING_TTL = 30.minutes

    # The dashboard's groups, or nil while they're prepared. The query takes most of a minute in
    # production, so a miss enqueues the job - once across every server - rather than running it here
    def fetch_group_snapshot
      json = RedisPool.conn { it.get(SNAPSHOT_KEY) }
      return parse_snapshot(json) if json

      enqueue_group_snapshot
      nil
    end

    def store_group_snapshot
      snapshot = ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) { {generated_at: Time.current, groups:} }
      RedisPool.conn { it.set(SNAPSHOT_KEY, snapshot.to_json, ex: SNAPSHOT_TTL.to_i) }
    ensure
      RedisPool.conn { it.del(PREPARING_KEY) }
    end

    def groups
      manufacturer_names = Cues.fetch_manufacturer_name_serials
      ActiveRecord::Base.connection.select_all(query).to_a.map do |group|
        group["manufacturer_name_serial"] = manufacturer_names[group["serial"]]
        group = group.merge("kind" => kind(group),
          "bike_ids" => JSON.parse(group["bike_ids"]),
          "organization_ids" => JSON.parse(group["organization_ids"] || "[]"),
          "first_at" => group["first_at"].in_time_zone,
          "last_at" => group["last_at"].in_time_zone)
        group.merge("cues" => Cues.group_cues(group))
      end
    end

    # The stolen veto outranks every other queue; a placeholder or part-number serial isn't evidence of anything,
    # so it outranks the rest
    def kind(group)
      return "stolen_history" if group["serial_stolen"]
      return "not_a_serial" if Cues.not_a_serial(group["serial"], manufacturer_names: Cues.group_manufacturer_names(group))
      return "internal_test" if group["test_count"] == group["record_count"]
      return "mixed_test" if group["test_count"].positive?
      return "large_group" if group["record_count"] >= LARGE_GROUP_MINIMUM
      return "handoff_priority" if group["handoff_priority"]
      return "pos_repeat" if group["pos_count"] == group["record_count"] && group["ever_claimed_count"].zero? && group["transfer_count"].zero? && group["email_count"] == 1 && group["missing_email_count"].zero? && group["organization_count"] == 1 && group["missing_organization_count"].zero?
      return "shop_customer" if group["record_count"] == 2 && group["pos_count"] == 1 && group["customer_count"] == 1 && group["pos_first"]
      return "same_identity" if Cues.single_contact?(group)

      "unresolved"
    end

    def serial_bikes(reference)
      Bike.unscoped.where(deleted_at: nil).where("example IS NOT TRUE AND likely_spam IS NOT TRUE")
        .where(manufacturer_id: reference.manufacturer_id, serial_normalized_no_space: reference.serial_normalized_no_space)
    end

    # Current, historical or recovered: any of them vetoes merging a whole serial
    def stolen_history_sql(table)
      "(#{table}.status = #{Bike::STATUS_ENUM[:status_stolen]} OR #{table}.current_stolen_record_id IS NOT NULL" \
        " OR EXISTS (SELECT 1 FROM stolen_records WHERE stolen_records.bike_id = #{table}.id))"
    end

    def stolen_serials(serials) = stolen_serial_bikes(serials).distinct.pluck(:serial_normalized_no_space)

    def stolen_serials?(serials) = stolen_serial_bikes(serials).exists?

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

    def stolen_serial_bikes(serials)
      Bike.unscoped.where(serial_normalized_no_space: serials.compact_blank).where(stolen_history_sql("bikes"))
    end

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
            coalesce(o.pos_kind IN (#{enum_sql(Organization::POS_KIND_ENUM, *POS_KINDS)}), false) pos,
            coalesce(o.origin IN (#{enum_sql(Ownership::ORIGIN_ENUM, *customer_origins)})
              AND coalesce(o.pos_kind, #{Organization::POS_KIND_ENUM[:no_pos]}) NOT IN (#{enum_sql(Organization::POS_KIND_ENUM, *Organization.pos_kinds.select { Organization.pos?(it) })}), false) customer,
            coalesce(o.claimed OR o.claimed_at IS NOT NULL, false) claimed,
            coalesce((o.claimed OR o.claimed_at IS NOT NULL) AND o.user_id IS NOT NULL AND o.creator_id = o.user_id
              AND o.creator_id IS DISTINCT FROM g.auto_user_id, false) self_registered,
            EXISTS (SELECT 1 FROM ownerships h WHERE h.bike_id = b.id AND (h.claimed OR h.claimed_at IS NOT NULL)) ever_claimed,
            EXISTS (SELECT 1 FROM ownerships h WHERE h.bike_id = b.id AND h.previous_ownership_id IS NOT NULL) transferred,
            EXISTS (SELECT 1 FROM marketplace_listings m WHERE m.item_type = 'Bike' AND m.item_id = b.id)
              OR EXISTS (SELECT 1 FROM marketplace_listings m JOIN bike_versions v ON m.item_type = 'BikeVersion' AND m.item_id = v.id WHERE v.bike_id = b.id) marketplace,
            coalesce(c.user_id IS NOT DISTINCT FROM o.user_id AND c.is_phone IS NOT TRUE AND lower(btrim(c.owner_email)) = lower(btrim(o.owner_email)), false) current_identity_matches,
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
          count(*) FILTER (WHERE #{Cues.review_contact_sql("email")})::integer review_contact_count,
          count(DISTINCT user_id)::integer account_count, count(*) FILTER (WHERE user_id IS NULL)::integer missing_account_count,
          count(DISTINCT organization_id)::integer organization_count, count(*) FILTER (WHERE organization_id IS NULL)::integer missing_organization_count,
          jsonb_agg(DISTINCT organization_id) FILTER (WHERE organization_id IS NOT NULL) organization_ids,
          min(created_at) first_at, max(created_at) last_at,
          coalesce(min(created_at) FILTER (WHERE pos) < min(created_at) FILTER (WHERE customer), false) pos_first,
          bool_or(serial_stolen) serial_stolen,
          count(*) = 2 AND count(*) FILTER (WHERE pos) = 1 AND count(*) FILTER (WHERE customer AND self_registered) = 1
            AND min(created_at) FILTER (WHERE pos) < min(created_at) FILTER (WHERE customer)
            AND count(*) FILTER (WHERE pos AND ever_claimed) = 0
            AND count(*) FILTER (WHERE transferred OR marketplace OR NOT current_identity_matches OR current_impound_record_id IS NOT NULL OR status IS DISTINCT FROM #{Bike::STATUS_ENUM[:status_with_owner]}) = 0
            AND count(DISTINCT email) = 1 AND count(email) = 2 AND count(DISTINCT user_id) = 1 AND count(user_id) = 2
            AND count(DISTINCT nullif(lower(btrim(frame_model)), '')) <= 1 AND count(DISTINCT year) <= 1
            AND count(DISTINCT nullif(lower(btrim(manufacturer_other)), '')) <= 1
            AND count(DISTINCT simple_serial) = 1
            AND EXISTS (SELECT 1 FROM manufacturers m WHERE m.id = manufacturer_id AND nullif(btrim(m.name), '') IS NOT NULL AND m.name <> 'Other') handoff_priority
        FROM registrations GROUP BY manufacturer_id, serial
        ORDER BY count(*) DESC, min(id)
      SQL
    end

    # A customer registering their own bike: the website, a shop's embed form or a sticker
    def customer_origins = Ownership::ORIGIN_WEBSITE_REG + %w[embed embed_extended embed_partial]

    def enqueue_group_snapshot
      return unless RedisPool.conn { it.set(PREPARING_KEY, Time.current.to_i, nx: true, ex: PREPARING_TTL.to_i) }

      BikeJobs::PrepareDuplicateReviewJob.perform_async
    rescue
      # Release the claim, so the next visit enqueues again rather than waiting out PREPARING_TTL
      RedisPool.conn { it.del(PREPARING_KEY) }
      raise
    end

    def enum_sql(enum, *keys) = enum.values_at(*keys.map(&:to_sym)).join(", ")

    def parse_snapshot(json)
      snapshot = JSON.parse(json)
      groups = snapshot["groups"].map do |group|
        group.merge("first_at" => Time.zone.parse(group["first_at"]), "last_at" => Time.zone.parse(group["last_at"]),
          "cues" => group["cues"].map { Cues::Cue.new(**it.symbolize_keys.merge(color: it["color"].to_sym)) })
      end
      {generated_at: Time.zone.parse(snapshot["generated_at"]), groups:}
    end

    conceal :customer_origins, :enqueue_group_snapshot, :enum_sql, :parse_snapshot, :stolen_serial_bikes, :query, :test_bikes_sql
  end
end
