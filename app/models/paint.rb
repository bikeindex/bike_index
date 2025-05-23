# == Schema Information
#
# Table name: paints
#
#  id                 :integer          not null, primary key
#  bikes_count        :integer          default(0), not null
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  color_id           :integer
#  manufacturer_id    :integer
#  secondary_color_id :integer
#  tertiary_color_id  :integer
#
class Paint < ApplicationRecord
  include FriendlyNameFindable

  validates_presence_of :name
  validates_uniqueness_of :name
  belongs_to :color
  belongs_to :manufacturer
  has_many :bikes

  belongs_to :secondary_color, class_name: "Color"
  belongs_to :tertiary_color, class_name: "Color"

  scope :official, -> { where("manufacturer_id IS NOT NULL") }
  scope :linked, -> { where("color_id IS NOT NULL") }
  scope :unlinked, -> { where("color_id IS NULL") }

  before_save :set_calculated_attributes

  before_create :associate_colors

  # TODO: Refactor this to be better
  def self.paint_name_parser(str)
    paint_str = str.clone.downcase
    paint_str.gsub!(/[\\\/"\-()?,&+;.]/, " ")

    # RAL colors. See wikipedia table for rough groupings. Many of the reds are pink, greys are brown, etc. by whatever
    paint_str.gsub!(/ral\s?([1-8])\d{3}/) do
      case Regexp.last_match[1].to_i
      when 1 then "yellow"
      when 2 then "orange"
      when 3 then "red"
      when 4 then "purple"
      when 5 then "blue"
      when 6 then "green"
      when 7 then "silver"
      when 8 then "brown"
      end
    end

    # Abbreviations
    paint_str.gsub!(/(\A|\s)bl?c?k(\s|\Z)/, " black ")
    paint_str.gsub!(/sli?ve?r?/, " silver ")
    paint_str.gsub!(/gra?e?y/, " silver ")
    paint_str.gsub!(/(\A|\s)wht?(\s|\Z)/, " white ")
    paint_str.gsub!(/whi?te?/, " white ")
    paint_str.gsub!(/(\A|\s)rd(\s|\Z)/, " red ")
    paint_str.gsub!(/gree?n/, " green ")
    paint_str.gsub!(/blue?/, " blue ")
    paint_str.gsub!(/purple?/, " purple ")
    paint_str.gsub!(/pi?nk/, " pink ")
    # ish
    paint_str.gsub!("bluish", "blue")
    paint_str.gsub!("reddish", "red")
    paint_str.gsub!(/-?ish( |\Z)/, " ")
    # Other colors we normalize
    paint_str.gsub!(/steel (blue|grey|gray|black)/, '\1')
    paint_str.gsub!("steel", " silver ")
    paint_str.gsub!("maroon", " red ")
    paint_str.gsub!("pearl", " white ")
    paint_str.gsub!("ivory", " white ")
    paint_str.gsub!(/(cream|creme)/, " white ")
    paint_str.gsub!("champagne", " white ")
    paint_str.gsub!("beige", " white ")
    paint_str.gsub!("carbon", " black ")
    paint_str.gsub!("composite", " black ")
    paint_str.gsub!(/(\A|\s)blu(\s|\Z)/, " blue ")
    paint_str.gsub!("navy", " blue ")
    paint_str.gsub!("celeste", " teal ")
    paint_str.gsub!("turquoise", " teal ")
    paint_str.gsub!("emerald", " green ")
    paint_str.gsub!("mint", " green ")
    paint_str.gsub!("titanium", " silver ")
    paint_str.gsub!("aluminum", " silver ")
    paint_str.gsub!("brushed", " silver ")
    paint_str.gsub!(/clear\s?coat/, " silver ")
    paint_str.gsub!(/(\A|\s)ti(\s|\Z)/, " silver ")
    paint_str.gsub!(/(\A|\s)tan(\s|\Z)/, " brown ")
    paint_str.gsub!(/(\A|\s)taupe(\s|\Z)/, " brown ")
    paint_str.gsub!("wood", " brown ")
    paint_str.gsub!("copper", " brown ")
    paint_str.gsub!("brass", " yellow ")
    paint_str.gsub!("bronze", " yellow ")
    paint_str.gsub!("mustard", " yellow ")
    paint_str.gsub!(/golde?n?/, " yellow ")
    paint_str.gsub!(/(\A|\s)crcl(\s|\Z)/, " silver ") # bad abbreviation of charcoal
    paint_str.gsub!("gunmetal", " silver ")
    paint_str.gsub!(/char(coa?l)?/, " silver ")
    paint_str.gsub!("graphite", " silver ")
    paint_str.gsub!("platinum", " silver ")
    paint_str.gsub!("nickel", " silver ")
    paint_str.gsub!("chrome", " silver ")
    paint_str.gsub!("quicksilver", " silver ")
    paint_str.gsub!(/burgu?a?ndy/, " red ")
    paint_str.strip.gsub(/\s+/, " ")
  end

  def unlinked?
    color_id.blank?
  end

  def linked?
    !unlinked?
  end

  def set_calculated_attributes
    self.name = name.downcase.strip
  end

  def associate_colors
    color_ids = {}
    Color.all.each do |color|
      color_ids[color.name.split(/\W+/).first.downcase] = color.id
    end
    paint_words = self.class.paint_name_parser(name).split(/\W+/).uniq
    used_ids = []

    # go through the paint words, add the colors id to the used ids if it's a known color
    paint_words.each { |w| used_ids << color_ids[w] if color_ids[w].present? }

    self.color_id = used_ids[0] if used_ids[0]
    self.secondary_color_id = used_ids[1] if used_ids[1]
    self.tertiary_color_id = used_ids[2] if used_ids[2]
    self
  end
end
