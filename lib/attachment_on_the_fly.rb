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
   puts("IN METHOD TO S MATCH+++---:Method: #{method}")
      return true
    end
    super
  end

  def method_missing(symbol , *args, &block )
    #puts("IN METHOD MISSING+++---:symbol: #{symbol}")
    @asset_id = 0
    args.each do |val|
      @asset_id = val
      puts ("VAL #{val}")
     end
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
    convert_command_path = (Paperclip.options[:command_path] ? Paperclip.options[:command_path] + "/" : "")

    prefix = ""

    if kind == "height"
      prefix = "S_" + height.to_s + "_HEIGHT_"
    elsif kind == "width"
      width = height
      prefix = "S_" + height.to_s + "_WIDTH_"
    elsif kind == "both"
      prefix = "S_" + height.to_s + "_" + height.to_s + "_"
    end

    puts("!!!!!!!!SELF++: #{self}")
    path = self.path
    url = self.url

    path_arr = path.split("/")
    file_name = path_arr.pop
    path = path_arr.join("/")

    url_arr = url.split("/")
    url_file_name = url_arr.pop
    url_path = url_arr.join("/")
    #just pop url_arry.pop
    
    original = path + "/" + self.original_filename
    newattchfilename = prefix + file_name
    newfilename = path + "/" + prefix + file_name
    new_path = url_path + "/" + prefix + file_name
    
    orig_arry = original.split("/")
    orig_arry.pop(2)
    thumbfile = orig_arry.join("/") + "/thumb/" + file_name if !windows?
    thumbfile = orig_arry.join("\\") + "\\thumb\\" + file_name if windows?


    return new_path  if  File.exist?(newfilename)

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


   #WINDOWS SUPPORT-Requires it to be in the PATH
   if windows?
      command = ""
      if kind == "height"
        # resize_image infilename, outfilename , 0, height
        command = "convert -colorspace RGB -geometry x#{height} -quality 100 -sharpen 1 \"#{original}\" \"#{newfilename}\" >NUL"
      elsif kind == "width"
        # resize_image infilename, outfilename, width
        command = "convert -colorspace RGB -geometry #{width} -quality 100 -sharpen 1 \"#{original}\" \"#{newfilename}\" >NUL"
      elsif kind == "both"
        # resize_image infilename, outfilename, height, width
        command = "convert -colorspace RGB -geometry #{width}x#{height} -quality 100 -sharpen 1 \"#{original}\" \"#{newfilename}\" >NUL"
      end
      
    else #it must be *Nix based.
         command = ""
  
      if kind == "height"
        # resize_image infilename, outfilename , 0, height
        command = "#{convert_command_path}convert -colorspace RGB -geometry x#{height} -quality 100 -sharpen 1 #{original} #{newfilename} 2>&1 > /dev/null"
      elsif kind == "width"
        # resize_image infilename, outfilename, width
        command = "#{convert_command_path}convert -colorspace RGB -geometry #{width} -quality 100 -sharpen 1 #{original} #{newfilename} 2>&1 > /dev/null"
      elsif kind == "both"
        # resize_image infilename, outfilename, height, width
        command = "#{convert_command_path}convert -colorspace RGB -geometry #{width}x#{height} -quality 100 -sharpen 1 #{original} #{newfilename} 2>&1 > /dev/null"
      end
    end#ending Windows/Linux commands
    
    `#{command}`

    if $? != 0
      raise AttachmentOnTheFlyError.new("Execution of convert failed. Please set path in Paperclip.options[:command_path] or ensure that file permissions are correct.")
    else
      puts ("saving...")
      puts ("-----++++----ABOUT SELF #{self}")
      puts ("-----++++----ASSET ID #{@asset_id}")
      img = Attachment.find_by_asset_id(@asset_id,:conditions=>{:main_image=>true})
      puts("IMG: #{img}")
      puts("+++-----NEW FILE NAME: #{newattchfilename}")
      img.attachment_file_name=newattchfilename
      img.save
      #delete the old
      puts("[ONTHEFLY]: DELETING ORIGINAL FILE...#{original}")
      puts("[ONTHEFLY]: CONVERTING ORIGINAL...")
      original = original.gsub(/[\/]/, '\\')
      puts("[ONTHEFLY]: ORIGINAL NOW IS #{original}")
      cmd = "del \"#{original}\"" if windows?
      cmd = "rm #{original}" if !windows?
      puts("[ONTHEFLY]: DELETED ORIGINAL FILE...")
      `#{cmd}`
      puts("[ONTHEFLY]: RENAMING THUMB...")
      puts("[ONTHEFLY]: THUMB PATH IS #{thumbfile}")
      if windows?
        cmd = "REN \"#{thumbfile}\" #{prefix + file_name}"
      else
        cmd = "MV #{thumbfile} #{prefix+file_name}"
      end
      `#{cmd}`
      puts ("[ONTHEFLY]: CHANGED THUMB NAME...")
      
      #we need to save the object to the database to make it so it will delete!
      #img=Attachment.new(:name=>"ontheflyimg",:created_at=>Time.now,:updated_at=>Time.now,
      #:attachment_file_name=>newfilename,:asset_id=>76,:attachment_file_size=>0,
      #:main_image=>0)
      #img.save
    end

    return new_path
  end
  
  def windows?
      !(RUBY_PLATFORM =~ /win32|mswin|mingw/).nil?
    end
    
end

class AttachmentOnTheFlyError < StandardError; end
