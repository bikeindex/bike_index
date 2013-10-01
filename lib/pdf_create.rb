module PdfCreate
  attr_accessor :bike
  require 'date'
  require 'time'
  
  def pdf_format bike
    @bike = bike
    # return file_name unless is_new?
    pdf = Prawn::Document.new
    render_pdf_document pdf
  end
  
  def base_name
    ".#{config.root}/public"
  end
  
  def file_name
    date = Date.today
    name = bike.name.sub(%r{\s},"-")
    "/uploads/pdf/#{name}_#{bike.id}D#{date}.pdf"
  end
  
  def render_pdf_document pdf
    cleanup
    render_stolen_banner( pdf )
    render_title( pdf )
    render_media( pdf )
    render_stolen_record( pdf )
    render_bike_info( pdf )
    pdf.render_file "#{base_name}#{file_name}"
    file_name
  end
  
  def render_stolen_banner pdf
    if is_stolen?
      reported_date = bike.stolen_records.last.created_at.to_s.split(%r{\s}).first
      pdf.bounding_box([0, pdf.cursor], width: 540, height: 22) do
        pdf.stroke_color important_color
        pdf.stroke_horizontal_rule
        pdf.pad_bottom(10) do
          pdf.text("<color rgb='#{important_color}'>Your #{bike.type} was reported stolen on #{reported_date}.</color>", :align => :center, :valign => :center, :inline_format => true)
        end
      end
      pdf.stroke_horizontal_rule
    end
  end
  
  def render_title pdf
    render_row_margin_if_stolen( pdf )
    pdf.fill_color text_color
    pdf.text "#{bike.frame_manufacture_year} #{bike.frame_model} by <b>#{bike.manufacturer.name}</b>", :size => 36, :inline_format => true, :align => :center
  end
  
  def render_stolen_record pdf
    if is_stolen?
      render_row_margin_if_stolen(pdf)
      pdf.stroke_color important_color
      pdf.stroke_horizontal_rule
      pdf.pad_top(10) do
        pdf.fill_color important_color
        pdf.text "<b>Stolen Bike Information:</b>", :inline_format => true
      end
      render_stolen_details pdf
    end
  end
  
  def render_stolen_details pdf
    render_row_margin(pdf,10)
    data=[]
    last_record = bike.stolen_records.last
    list_data = {
      phone_number:           last_record.phone,
      locking_description:    last_record.locking_description,
      locking_circumvented:   last_record.lock_defeat_description,
      date_stolen:            last_record.date_stolen.to_s.split(%r{\s}).first,
      location:               last_record.street,
      description:            last_record.theft_description,
      police_report_number:   last_record.police_report_number
    }
    list_data.each_with_index do |item, i|
      arr = filter_hash_clean_array(item)
      data << arr
    end
    pdf.table(data) do
      cells.borders = []
      cells.size = 11
      cells.padding = [0, 30, 2, 10]
    end
  end
  
  def render_media pdf
    unless bike.thumb_path.nil?
      render_row_margin( pdf )
      pdf.image "#{Prawn::DATADIR}#{bike.thumb_path.gsub(%r{/small},'/large')}", :height => 120, :position => :center
    end
  end
  
  def render_bike_info pdf
    render_row_margin( pdf )
    pdf.stroke_color border_color
    pdf.stroke_horizontal_rule
    pdf.pad_top(10) do
      pdf.fill_color text_color
      pdf.text "<b>Bike Information</b>", :inline_format => true
    end
    render_bike_details( pdf )
  end
  
  def render_bike_details pdf
    render_row_margin(pdf,10)
    j=0
    data = []
    bike_info = {
      cycle_type:         bike.type,
      serial:             bike.serial_number,
      manufacture:        bike.manufacturer.name,
      model:              bike.frame_model,
      year:               bike.frame_manufacture_year,
      seat_tube_length:   bike.seat_tube_length,
      front_wheel:        bike.front_wheel_size.name,
      rear_wheel:         bike.rear_wheel_size.name,
      handlebar_type:     bike.handlebar_type.name,
      primary_color:      bike.primary_frame_color.name,
      secondary_color:    bike.secondary_frame_color.name,
      frame_material:     bike.frame_material.name,
      rear_gears:         bike.rear_gear_type.name,
      front_gears:        bike.front_gear_type.name
    }    
    bike_info.each_with_index do |item, i|
      if i < bike_info.size/2
        data << filter_hash_clean_array(item)
      else
        arr = filter_hash_clean_array(item)
        data[j] << arr[0]
        data[j] << arr[1]
        j += 1
      end
    end
    pdf.table(data) do
      cells.borders = []
      cells.size = 11
      cells.each_with_index do |cell, i|
        if i.even?
          cell.text_color = '999999'
          cell.padding = [0, 30, 2, 10]
        elsif i.odd?
          cell.text_color = '222222'
          cell.padding = [0, 40, 2, 0]
        end
      end
    end
  end
  
  def render_bike_components
    
  end
  
  def cleanup file=nil
    path = file || base_name+file_name
    destroy_pdf( path ) if File.exist?(path)
  end
  
  def render_row_margin pdf, size=20
    pdf.move_down size
  end
  
  def render_row_margin_if_stolen pdf
    if is_stolen?
      pdf.move_down 20
    end
  end
    
private
  
  def filter_hash_clean_array item
    item.map.with_index do |x,j|
      if j == 0
        x = x.to_s.sub(%r{\_}," ").capitalize
      end
      x
    end
  end
  
  def filter_name name
    name = name.sub(%r{\s},"-") # replace white space
    name = name.sub(%r{\H}, "") # remove non alpha numerics
    name
  end
  
  def is_stolen?
    bike.stolen ? true : false
  end
    
  def is_new?
    # returns true if file was created more than 15mins ago or file doesn't exists
    path = "#{base_name+file_name}"
    if File.exist? path
      return (Time.parse(File.new(path).mtime.to_s) + 900) <= Time.parse(Time.now.to_s)
    end
    true
  end
  
  def destroy_pdf file
    File.delete(file) if is_new?
  end
  
  def important_color
    "FF0000"
  end
  
  def header_color
    "999999"
  end
  
  def text_color
    "222222"
  end
  
  def border_color
    "DDDDDD"
  end  
end