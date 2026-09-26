# frozen_string_literal: true

# Groups production's missing-manufacturer counts by manufacturer slug and splits them into
# ones that match an existing manufacturer and candidates for a new one. Run with:
#   bin/rails runner .claude/skills/manufacturers/scripts/candidates.rb tmp/missing_manufacturers.json [min_count]

require "csv"
require "net/http"

counts_path, min_count = ARGV
abort("usage: bin/rails runner #{__FILE__} <missing_manufacturers.json> [min_count]") unless counts_path
min_count = (min_count || 3).to_i
counts = JSON.parse(File.read(counts_path)).fetch("manufacturer_other_counts")

# Production's list, rather than the local database's
manufacturers_csv = Net::HTTP.get(URI("https://bikeindex.org/manufacturers.csv")).force_encoding("UTF-8")
existing = CSV.parse(manufacturers_csv, headers: true).each_with_object({}) do |row, slugs|
  [row["name"], row["alternate_name"]].compact_blank.each { slugs[Slugifyer.manufacturer(it)] = row["name"] }
end

# manufacturer_other is typed by whoever registered the bike - print it as short, printable data
def display(name) = name.gsub(/[^[:print:]]/, "").truncate(60).inspect

groups = counts.group_by { |name, _count| Slugifyer.manufacturer(name) }.except("").map do |slug, pairs|
  {slug:, count: pairs.sum(&:last), variants: pairs.sort_by { -it.last }.first(4).map { display(it.first) },
   existing: existing[slug], prefix_of: existing[slug.split("_").first]}
end.sort_by { -it[:count] }

matching, unmatched = groups.partition { it[:existing] }

puts "== Match an existing manufacturer (#{matching.count}) =="
puts %w[count manufacturer variants].join("\t")
matching.each { puts [it[:count], it[:existing], it[:variants].join(" | ")].join("\t") }

candidates = unmatched.select { it[:count] >= min_count }
puts "\n== Candidates with #{min_count}+ bikes (#{candidates.count} of #{unmatched.count}) =="
puts %w[count variants starts_with_manufacturer].join("\t")
candidates.each { puts [it[:count], it[:variants].join(" | "), it[:prefix_of]].join("\t") }
