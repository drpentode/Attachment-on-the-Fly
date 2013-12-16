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
    if method.to_s.match(/^(cls|s)_[0-9]+_[0-9]+$/) ||
      method.to_s.match(/^(cls|s)_[0-9]+_(width|height|both)$/) ||
      method.to_s.match(/^(cls|s)[0-9]+$/)
      return true
    end
    super
  end

  def method_missing(symbol , *args, &block )
    # We are looking for methods with S_[number]_[number]_(height | width | proportion)
    # Height and width
    # Check to see if file exists, if so return string
    # if not generate image and return string to file
    image_name = nil
    parameters = args.shift
    parameters ||= {}

    if symbol.to_s.match(/^(cls|s)_[0-9]+_[0-9]+$/)
      values = symbol.to_s.split("_")
      height = values[1].to_i
      width = values[2].to_i
      image_name = generate_image("both", height, width, parameters)
    elsif symbol.to_s.match(/^(cls|s)_[0-9]+_(width|height|both)$/)
      values = symbol.to_s.split("_")
      size = values[1].to_i
      kind = values[2]
      image_name = generate_image(kind, size, size, parameters)
    elsif symbol.to_s.match(/^(cls|s)[0-9]+$/)
      values = symbol.to_s.split("s")
      size = values[1].to_i
      kind = "width"
      image_name = generate_image(kind, size, size, parameters)
    else
      # if our method string does not match, we kick things back up to super ... this keeps ActiveRecord chugging along happily
      super
    end
    return image_name
  end

  def generate_image(kind, height = 0, width = 0, parameters = {})
    convert_command_path = (Paperclip.options[:command_path] ? Paperclip.options[:command_path] + "/" : "")
    parameters.symbolize_keys!
    [:extension, :quality].each do |opt|
      parameters.reverse_merge!({opt => Paperclip.options[opt]}) if Paperclip.options[opt]
    end
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
    presuffix = parameters.map{|k,v| "#{k}_#{v}" }.join('___') + "_q_#{quality}_"
    prefix = "#{prefix}#{presuffix}_"
    prefix = "#{prefix}#{Paperclip.options[:version_prefix]}_" if Paperclip.options[:version_prefix]

    path = self.path
    url = self.url

    path_arr = path.split("/")
    file_name = path_arr.pop
    path = path_arr.join("/")

    base_arr = file_name.split('.');
    original_extension = extension = base_arr.pop
    base_name = base_arr.join('.')
    extension = parameters[:extension] || extension
    parameters.delete :extension

    url_arr = url.split("/")
    url_file_name = url_arr.pop
    url_path = url_arr.join("/")

    original = path + "/" + self.original_filename
    newfilename = path + "/" + prefix + base_name +  '.' + extension
    fallback_newfilename = path + "/" + prefix + base_name +  '.' + original_extension
    new_path = url_path + "/" + prefix + base_name + '.' + extension
    fallback_new_path = url_path + "/" + prefix + base_name + '.' + original_extension
    return new_path if File.exist?(newfilename)

    if !File.exist?(original)
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

    options_for_extension = ""
    if original_extension != extension && has_alpha?(original)
      # Converting extension with alpha channel is problematic.
      # Fall back to original extension.
      Paperclip.log("Ignoring extension parameter because original file is transparent")
      newfilename = fallback_newfilename
      new_path = fallback_new_path
    end

    colorspace = parameters[:colorspace] || Paperclip.options[:colorspace]
    colorspace_opt = "-colorspace #{colorspace}" if colorspace

    base_command = "#{convert_command_path}convert #{colorspace_opt} -strip -geometry"

    if kind == "height"
      # resize_image infilename, outfilename , 0, height
      command = "#{base_command} x#{height} -quality #{quality} -sharpen 1 '#{original}' '#{newfilename}' 2>&1 > /dev/null"
    elsif kind == "width"
      # resize_image infilename, outfilename, width
      command = "#{base_command} #{width} -quality #{quality} -sharpen 1 '#{original}' '#{newfilename}' 2>&1 > /dev/null"
    elsif kind == "both"
      # resize_image infilename, outfilename, height, width
      command = "#{base_command} #{width}x#{height} -quality #{quality} -sharpen 1 '#{original}' '#{newfilename}' 2>&1 > /dev/null"
    end

    convert_command command

    return new_path
  end

  def convert_command command
    `#{command}`
    if ($? != 0)
      raise AttachmentOnTheFlyError.new("Execution of convert failed. Please set path in Paperclip.options[:command_path] or ensure that file permissions are correct. Failed trying to do: #{command}")
    end
  end

  def has_alpha? image
    identify_command_path = (Paperclip.options[:identify_command_path] ? Paperclip.options[:identify_command_path] + "/" : "")
    # http://stackoverflow.com/questions/2581469/detect-alpha-channel-with-imagemagick
    command = "#{identify_command_path}identify -format '%[channels]' '#{image}'"
    result = `#{command}`
    if ($? != 0)
      raise AttachmentOnTheFlyError.new("Execution of identify failed. Please set path in Paperclip.options[:identify_command_path] or ensure that file permissions are correct. Failed trying to do: #{command}")
    end
    result && result.chomp == "rgba"
  end
end

class AttachmentOnTheFlyError < StandardError; end
