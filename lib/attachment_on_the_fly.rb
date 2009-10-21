#
# Methods to allow attachment modification on-the-fly ... a replacement for PhotoActiveRecord that integrates with Paperclip
# the paperclip attachment attribute should be called "attachment" on the model
#
Paperclip::Attachment.class_eval do
  require 'ftools'
  require 'fileutils'
  require 'tempfile'
  
  # we respond to s_ and cls_
  def respond_to?(method,*args, &block)
    if method.to_s.match(/^s_[0-9]+_[0-9]+/) ||  method.to_s.match(/^s_[0-9]+_[a-z]+/) || method.to_s.match(/^s[0-9]+/)  ||
			method.to_s.match(/^cls_[0-9]+_[0-9]+/) ||  method.to_s.match(/^cls_[0-9]+_[a-z]+/) || method.to_s.match(/^cls[0-9]+/)
      return true
    end
    super
  end
  
  def method_missing(symbol , *args, &block )
    # We are looking for methods with S_[number]_[number]_(height | width | proportion)
    # Height and width
    # Check to see if file exist if so return string
    # if not generate image and return string to file  Fiel is in format S_Height_x_Width_FILE_NAME
	  image_name = nil
    if symbol.to_s.match(/^s_[0-9]+_[0-9]+/) || symbol.to_s.match(/^cls_[0-9]+_[0-9]+/)
      values = symbol.to_s.split("_")
      height = values[1]
      width = values[2]
      image_name = generate_image("both", height.to_i, width.to_i)
    elsif symbol.to_s.match(/^s_[0-9]+_[a-z]+/)   || symbol.to_s.match(/^cls_[0-9]+_[a-z]+/)
      values = symbol.to_s.split("_")
      size = values[1]
      who = values[2]
      image_name = generate_image(who, size.to_i)
    elsif symbol.to_s.match(/^s[0-9]+/)  || symbol.to_s.match(/^cls[0-9]+/)
      values = symbol.to_s.split("s")
      size = values[1]
      who = "width"
      image_name = generate_image(who, size.to_i)
	  else
	    # if our method string does not match, we kick things back up to super ... this keeps ActiveRecord chugging along happily
	    super
	  end
	  
	  return image_name
	end
	
	def generate_image(kind, height = 0, width = 0)
    prefix = ""
    
    if kind == "height"
      prefix = "S_" + height.to_s + "_HEIGHT_" 
    elsif kind == "width"
      width = height
      prefix = "S_" + height.to_s + "_WIDTH_"
    elsif kind == "both"
      prefix = "S_" + height.to_s + "_" + height.to_s + "_"
    end
    
    path = instance.attachment.path
    path_arr = path.split("/")
    file_name = path_arr.pop
    path = path_arr.join("/")
    
    original = path + "/" + instance.attachment.original_filename
    newfilename = path + "/" + prefix + file_name
    
    return newfilename  if  File.exist?(newfilename)
    
    if  !File.exist?(original)
      return newfilename
    end

    if kind == "height"
      # resize_image infilename, outfilename , 0, height
      `convert -colorspace RGB -geometry x#{height} -quality 100 #{original} #{newfilename} 2>&1 > /dev/null`
    elsif kind == "width"
      # resize_image infilename, outfilename, width
      `convert -colorspace RGB -geometry #{width} -quality 100 #{original} #{newfilename} 2>&1 > /dev/null`
    elsif kind == "both"
      # resize_image infilename, outfilename, height, width
      `convert -colorspace RGB -geometry #{height}x#{height} -quality 100 #{original} #{newfilename} 2>&1 > /dev/null`
    end

    return newfilename
  end
end