require File.dirname(__FILE__) + '/spec_helper'

require "open-uri"
require "net/http"
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

describe "Upload" do
  def setup_db
    ActiveRecord::Schema.define(:version => 1) do
      create_table :photos do |t|
        t.column :image, :string
      end

      create_table :attachments do |t|
        t.column :file, :string
      end
    end
  end

  def drop_db
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end

  class PhotoUploader < CarrierWave::Uploader::Base
    include CarrierWave::MiniMagick

    version :small do
      process :resize_to_fill => [120, 120]
    end

    def store_dir
      "photos"
    end
  end

  class AttachUploader < CarrierWave::Uploader::Base
    include CarrierWave::MiniMagick

    def store_dir
      "attachs"
    end
  end

  class Photo < ActiveRecord::Base
    mount_uploader :image, PhotoUploader
  end

  class Attachment < ActiveRecord::Base
    mount_uploader :file, AttachUploader
  end


  before :all do
    setup_db
  end

  after :all do
    drop_db
  end

  describe "Upload Image" do
    context "should upload image" do
      before(:all) do
        @file = load_file("foo.jpg")
        @file1 = load_file("foo.gif")
        @photo = Photo.new(:image => @file)
        @photo1 = Photo.new(:image => @file1)
      end

      it "should upload file" do
        expect(@photo.save).to eq true
        expect(@photo1.save).to eq true
      end

      it "should get uploaded file" do
        img = open(@photo.image.url)
        expect(img.size).to eq @file.size
        img1 = open(@photo1.image.url)
        expect(img1.size).to eq @file1.size
      end

      it "sholud get small version uploaded file" do
        expect(open(@photo.image.small.url)).not_to eq nil
        expect(open(@photo1.image.small.url)).not_to eq nil
      end
    end

    context "should update zip" do
      before(:all) do
        @file = load_file("foo.zip")
        @attachment = Attachment.new(:file => @file)
      end

      it "should upload file" do
        expect(@attachment.save).to eq true
      end

      it "should get uploaded file" do
        attach = open(@attachment.file.url)
        expect(attach.size).to eq @file.size
      end

      it "should delete old file when upload a new file again" do
        old_url = @attachment.file.url
        @attachment.file = load_file("foo.gif")
        @attachment.save
        res = Net::HTTP.get_response(URI.parse(old_url))
        expect(res.code).to eq "404"
      end
    end
  end
end
