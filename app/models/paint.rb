class Paint < ActiveRecord::Base
  attr_accessible :name,
    :color_id,
    :secondary_color_id,
    :tertiary_color_id,
    :manufacturer_id

  validates_presence_of :name
  validates_uniqueness_of :name
  belongs_to :color
  belongs_to :manufacturer
  has_many :bikes

  belongs_to :secondary_color, class_name: 'Color'
  belongs_to :tertiary_color, class_name: 'Color'

  scope :official, where("manufacturer_id IS NOT NULL")

  before_save { |p| p.name = p.name.downcase.strip }

  def self.fuzzy_name_find(n)
    if !n.blank?
      self.find(:first, conditions: [ "lower(name) = ?", n.downcase.strip ])
    else
      nil
    end
  end

  before_create :associate_colors
  def associate_colors
    color_ids = {}
    Color.all.each do |color|
      color_ids[color.name.split(/\W+/).first.downcase] = color.id
    end
    paint_words = paint_name_parser(name.clone).split(/\W+/).uniq
    used_ids = []

    # go through the paint words, add the colors id to the used ids if it's a known color
    paint_words.each { |w| used_ids << color_ids[w] if color_ids[w].present? }

    self.color_id = used_ids[0] if used_ids[0]
    self.secondary_color_id = used_ids[1] if used_ids[1]
    self.tertiary_color_id = used_ids[2] if used_ids[2]
    self
  end

  def paint_name_parser(paint_str)
    paint_str.gsub!(/[\\\/\"\-\()\?,\&\+\;\.]/, ' ')

    # RAL colors. See wikipedia table for rough groupings. Many of the reds are pink, greys are brown, etc. by whatever
    paint_str.gsub!(/ral\s?([1-8])\d{3}/) {
      case Regexp.last_match[1].to_i
      when 1 then "yellow"
      when 2 then "orange"
      when 3 then "red"
      when 4 then "purple"
      when 5 then "blue"
      when 6 then "green"
      when 7 then "silver"
      when 8 then "brown"
      #when 9 then "" This is white or black or gray
      end
    }

    paint_str.gsub!(/bluish/, 'blue')
    paint_str.gsub!(/reddish/, 'red')
    paint_str.gsub!(/ish( |\Z)/, ' ')
    paint_str.gsub!(/steel (blue|grey|gray|black)/, '\1')
    paint_str.gsub!(/steel/, 'raw')
    paint_str.gsub!(/maroon/, 'red')
    paint_str.gsub!(/(\A|\s)rd(\s|\Z)/, ' red ')
    paint_str.gsub!(/pearl/, 'white')
    paint_str.gsub!(/ivory/, 'white')
    paint_str.gsub!(/(cream|creme)/, 'white')
    paint_str.gsub!(/champagne/, 'white')
    paint_str.gsub!(/(\A|\s)wht?(\s|\Z)/, ' white ')
    paint_str.gsub!(/beige/, 'white')
    paint_str.gsub!(/(\A|\s)bl?k(\s|\Z)/, ' black ')
    paint_str.gsub!(/carbon/, 'black')
    paint_str.gsub!(/composite/, 'black')
    paint_str.gsub!(/celeste/, 'blue')
    paint_str.gsub!(/(\A|\s)blu(\s|\Z)/, ' blue ')
    paint_str.gsub!(/navy/, 'blue')
    paint_str.gsub!(/turquoise/, 'teal')
    paint_str.gsub!(/emerald/, 'green')
    paint_str.gsub!(/titanium/, 'raw')
    paint_str.gsub!(/aluminum/, 'raw')
    paint_str.gsub!(/brushed/, 'raw')
    paint_str.gsub!(/clear\s?coat/, 'raw')
    paint_str.gsub!(/(\A|\s)ti(\s|\Z)/, ' raw ')
    paint_str.gsub!(/(\A|\s)tan(\s|\Z)/, ' brown ')
    paint_str.gsub!(/(\A|\s)taupe(\s|\Z)/, ' brown ')
    paint_str.gsub!(/wood/, 'brown')
    paint_str.gsub!(/copper/, 'brown')
    paint_str.gsub!(/brass/, 'yellow')
    paint_str.gsub!(/bronze/, 'yellow')
    paint_str.gsub!(/mustard/, 'yellow')
    paint_str.gsub!(/golde?n?/, 'yellow')
    paint_str.gsub!(/(\A|\s)crcl(\s|\Z)/, ' silver ') #bad abbreviation of charcoal
    paint_str.gsub!(/gunmetal/, 'silver')
    paint_str.gsub!(/char(coa?l)?/, 'silver')
    paint_str.gsub!(/graphite/, 'silver')
    paint_str.gsub!(/platinum/, 'silver')
    paint_str.gsub!(/nickel/, 'silver')
    paint_str.gsub!(/chrome/, 'silver')
    paint_str.gsub!(/sli?ve?r?/, 'silver')
    paint_str.gsub!(/quicksilver/, 'silver')
    paint_str.gsub!(/gr(a|e)y/, ' silver ')
    paint_str.gsub!(/burgu?a?ndy/, "red")
    paint_str
  end

end
