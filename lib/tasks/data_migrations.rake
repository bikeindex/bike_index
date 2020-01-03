include ActionView::Helpers::NumberHelper

def print_progress(curr, total_count)
  total = number_with_delimiter(total_count)
  digits = total.to_s.length

  count = [number_with_delimiter(curr).to_s.rjust(digits, " "), total].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(7, " ")

  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end

def rename_feature_slug(direction, slug)
  case direction
  when :up
    slug == "bike_codes" ? "bike_stickers" : slug
  when :down
    slug == "bike_stickers" ? "bike_codes" : slug
  end
end

namespace :data do
  namespace :bike_codes_to_bike_stickers do
    desc "Migrate bike_codes feature slug to bike_stickers"
    task up: :environment do
      ActiveRecord::Base.transaction do
        PaidFeature.where("feature_slugs @> ?", "{bike_codes}").find_each do |pf|
          pf.feature_slugs = pf.feature_slugs.map { |slug| rename_feature_slug(:up, slug) }
          pf.save
        end
        Invoice.where("child_paid_feature_slugs ? :slug", slug: "bike_codes").find_each do |inv|
          inv.child_paid_feature_slugs = inv.child_paid_feature_slugs.map { |slug| rename_feature_slug(:up, slug) }
          inv.save
        end
        Organization.where("paid_feature_slugs ? :slug", slug: "bike_codes").find_each do |org|
          org.paid_feature_slugs = org.paid_feature_slugs.map { |slug| rename_feature_slug(:up, slug) }
          org.save
        end
      end
    end

    desc "Reverse bike_codes to bike_stickers migration"
    task down: :environment do
      ActiveRecord::Base.transaction do
        PaidFeature.where("feature_slugs @> ?", "{bike_stickers}").find_each do |pf|
          pf.feature_slugs = pf.feature_slugs.map { |slug| rename_feature_slug(:down, slug) }
          pf.save
        end
        Invoice.where("child_paid_feature_slugs ? :slug", slug: "bike_stickers").find_each do |inv|
          inv.child_paid_feature_slugs = inv.child_paid_feature_slugs.map { |slug| rename_feature_slug(:down, slug) }
          inv.save
        end
        Organization.where("paid_feature_slugs ? :slug", slug: "bike_stickers").find_each do |org|
          org.paid_feature_slugs = org.paid_feature_slugs.map { |slug| rename_feature_slug(:down, slug) }
          org.save
        end
      end
    end
  end
end
