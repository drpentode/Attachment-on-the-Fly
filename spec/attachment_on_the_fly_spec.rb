require_relative './spec_helper'

describe "Attachment on the fly mixin" do

  subject { Paperclip::Attachment.new }

  context "#respond_to?" do
    method_names = %w{s125 cls125 s_125_250 cls_125_250
      s_125_width cls_125_width s_125_height cls_125_height
      s_125_both cls_125_both
    }

    method_names.each do |method_name|
      it { should respond_to(method_name.to_sym) }
    end

    it { should_not respond_to(:x_125_250) }
    it { should_not respond_to(:s_125_250foo) }
    it { should_not respond_to(:S_125_250) }
  end

  context "#method_missing" do

    context "translates method into a generate image call" do
      method_name_to_generate_image_call = {
        :s_125_225 => ["both", 125, 225, {}],
        :s125 => ["width", 125, 125, {}],
        :s_125_height => ["height", 125, 125, {}],
        :s_125_width => ["width", 125, 125, {}],
        :s_125_both => ["both", 125, 125, {}]
      }

      method_name_to_generate_image_call.each do |method_name, generate_image_args|
        it "#{method_name}" do
          subject.should_receive(:generate_image).with(*generate_image_args)
          subject.send(method_name)
        end
      end

      it "passes parameters through as well" do
        subject.should_receive(:generate_image).with("width", 125, 125, {:quality => 90, :extension => "jpeg", :colorspace => "sRGB"})
        subject.s_125_width :quality => 90, :extension => "jpeg", :colorspace => "sRGB"
      end
    end
  end

  context "#generate_image" do

    context "it should generate a new image" do
      method_name_to_expectations = {
        :s_125_width => {
          :new => "/S_125_WIDTH__q_100__path.png",
          :regex => /-geometry 125 /
        },
        :s_125_height => {
          :new => "/S_125_HEIGHT__q_100__path.png",
          :regex => /-geometry x125 /
        },
        :s_125_both => {
          :new => "/S_125_125__q_100__path.png",
          :regex => /-geometry 125x125 /
        }
      }
      method_name_to_expectations.each do |method_name, expected|
        it "for #{method_name}" do
          File.should_receive(:exist?).with(expected[:new]).and_return(false)
          File.should_receive(:exist?).with("//file.png").and_return(true)
          subject.should_receive(:convert_command).with(expected[:regex])
          subject.send(method_name)
        end
      end

      it "passes in parameters for quality" do
        File.should_receive(:exist?).with("/S_125_WIDTH__q_75__path.png").and_return(false)
        File.should_receive(:exist?).with("//file.png").and_return(true)
        subject.should_receive(:convert_command).with(/-quality 75/)
        subject.s_125_width :quality => 75
      end

      it "passes in parameters for extension" do
        File.should_receive(:exist?).with("/S_125_WIDTH_extension_jpeg_q_75__path.jpeg").and_return(false)
        File.should_receive(:exist?).with("//file.png").and_return(true)
        subject.should_receive(:convert_command).with(/-quality 75/)
        subject.should_receive(:has_alpha?).with("//file.png").and_return(false)
        subject.s_125_width(:quality => 75, :extension => "jpeg").should == "/S_125_WIDTH_extension_jpeg_q_75__path.jpeg"
      end

      it "preserves original extension if file has alpha channel" do
        File.should_receive(:exist?).with("/S_125_WIDTH_extension_jpeg_q_75__path.jpeg").and_return(false)
        File.should_receive(:exist?).with("//file.png").and_return(true)
        subject.should_receive(:convert_command).with(/-quality 75/)
        subject.should_receive(:has_alpha?).with("//file.png").and_return(true)
        subject.s_125_width(:quality => 75, :extension => "jpeg").should == "/S_125_WIDTH_extension_jpeg_q_75__path.png"
      end

      it "passes in parameters for colorspace" do
        File.should_receive(:exist?).with("/S_125_WIDTH_colorspace_sRGB_q_100__path.png").and_return(false)
        File.should_receive(:exist?).with("//file.png").and_return(true)
        subject.should_receive(:convert_command).with(/-colorspace sRGB/)
        subject.s_125_width(:colorspace => "sRGB").should == "/S_125_WIDTH_colorspace_sRGB_q_100__path.png"
      end
    end
  end

  context "S3 storage" do
    subject do
      attachment  = Paperclip::Attachment.new
      options     = attachment.instance_variable_get("@options") || {}
      attachment.instance_variable_set("@options", options.merge({storage: :s3}))
      attachment
    end

    before(:each) do
      rails_const = {}
      rails_const.define_singleton_method(:root){ "" }
      stub_const("Rails", rails_const)
    end

    it "raises error if original file does not exist at S3" do
      expect(subject).to receive(:asked_file_exist?) { false }
      expect(subject).to receive(:original_file_exist?) { false }
      allow(Paperclip).to receive(:options).and_return(Paperclip.options.merge({whiny:true}))
      expect { subject.s_125_width}.to raise_error(AttachmentOnTheFlyError)
    end

    it "downloads original file from S3 and uploads copy back" do
      expect(subject).to receive(:asked_file_exist?) { false }
      expect(subject).to receive(:original_file_exist?) { true }
      expect(subject).to receive(:download_file)
      expect(subject).to receive(:convert_command)
      expect(subject).to receive(:upload_converted_file)
      subject.s_125_width.should == "/S_125_WIDTH__q_100__path.png"
    end

    it "returns url instantly if resized version exists" do
      expect(subject).to receive(:asked_file_exist?).and_return(true)
      expect(subject).not_to receive(:original_file_exist?)
      expect(subject).not_to receive(:download_file)
      expect(subject).not_to receive(:convert_command)
      expect(subject).not_to receive(:upload_converted_file)
      subject.s_125_width.should == "/S_125_WIDTH__q_100__path.png"
    end
  end

end
