#
# Methods to allow attachment modification on-the-fly
# the paperclip attachment attribute should be called "attachment" on the model
#
Paperclip::Attachment.class_eval do
  require 'ftools' if RUBY_VERSION < "1.9"
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
    parameters = args.shift    
    parameters ||= {:quality => 100}
    
    if symbol.to_s.match(/^s_[0-9]+_[0-9]+/) || symbol.to_s.match(/^cls_[0-9]+_[0-9]+/)
      values = symbol.to_s.split("_")
      height = values[1]
      width = values[2]
      image_name = generate_image("both", height.to_i, width.to_i,parameters)
    elsif symbol.to_s.match(/^s_[0-9]+_[a-z]+/)   || symbol.to_s.match(/^cls_[0-9]+_[a-z]+/)
      values = symbol.to_s.split("_")
      size = values[1]
      who = values[2]
      image_name = generate_image(who, size.to_i,0,parameters)
    elsif symbol.to_s.match(/^s[0-9]+/)  || symbol.to_s.match(/^cls[0-9]+/)
      values = symbol.to_s.split("s")
      size = values[1]
      who = "width"
      image_name = generate_image(who, size.to_i,0,parameters)
    else
      # if our method string does not match, we kick things back up to super ... this keeps ActiveRecord chugging along happily
      super
    end
    return image_name
  end

  def generate_image(kind, height = 0, width = 0,parameters = {})
    convert_command_path = (Paperclip.options[:command_path] ? Paperclip.options[:command_path] + "/" : "")
    parameters.symbolize_keys!
    quality = parameters[:quality] ||= 100
    parameters.delete :quality
    
    prefix = ""

    if kind == "height"
      prefix = "S_" + height.to_s + "_HEIGHT_"
    elsif kind == "width"
      width = height
      prefix = "S_" + height.to_s + "_WIDTH_"
    elsif kind == "both"
      prefix = "S_" + width.to_s + "_" + height.to_s + "_"
    end
    presufix = parameters.map{|k,v| "#{k}_#{v}" }.join('___')+ '_q_' + quality.to_s
    prefix = "_#{prefix}#{presufix}_"
   
    
    path = self.path
    url = self.url

    path_arr = path.split("/")
    file_name = path_arr.pop
    path = path_arr.join("/")
    
    base_arr = file_name.split('.');
    extension = base_arr.pop
    base_name = base_arr.join('.')
    extension = parameters[:extension] || extension
    parameters.delete :extension
    

    url_arr = url.split("/")
    url_file_name = url_arr.pop
    url_path = url_arr.join("/")

    original = path + "/" + self.original_filename
    suffix = File.mtime(__FILE__).strftime("%y-%m-%d-%H:%i:%s")
    newfilename = path + "/" + prefix + base_name + suffix + '.' + extension
    new_path = url_path + "/" + prefix + base_name + suffix + '.' + extension

    return new_path  if  File.exist?(newfilename) && File.mtime(original) < File.mtime(newfilename)

    if  !File.exist?(original)
      if Paperclip.options[:whiny]
        raise AttachmentOnTheFlyError.new("Original asset could not be read from disk at #{original}")
      else
        Paperclip.log("Original asset could not be read from disk at #{original}")
        if Paperclip.options[:missing_image_path]
          return Paperclip.options[:missing_image_path]
        else
          Paperclip.log("Please configure Paperclip.options[:missing_image_path] to prevent return of broken image path")
          return new_path
        end
      end
    end

    command = ""

    if kind == "height"
      # resize_image infilename, outfilename , 0, height
      command = "#{convert_command_path}convert -strip  -geometry x#{height} -quality #{quality} -sharpen 1 '#{original}' '#{newfilename}' 2>&1 > /dev/null"
    elsif kind == "width"
      # resize_image infilename, outfilename, width
      command = "#{convert_command_path}convert -strip -geometry #{width} -quality #{quality} -sharpen 1 '#{original}' '#{newfilename}' 2>&1 > /dev/null"
    elsif kind == "both"
      # resize_image infilename, outfilename, height, width
      command = "#{convert_command_path}convert -strip -geometry #{width}x#{height} -quality #{quality} -sharpen 1 '#{original}' '#{newfilename}' 2>&1 > /dev/null"
    end
    
    
    `#{command}`

    if ($? != 0)
      raise AttachmentOnTheFlyError.new("Execution of convert failed. Please set path in Paperclip.options[:command_path] or ensure that file permissions are correct.")
    end

    return new_path
  end
end

class AttachmentOnTheFlyError < StandardError; end

