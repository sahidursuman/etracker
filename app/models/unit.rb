require 'barby'
require 'barby/barcode/code_128'
require 'barby/outputter/rmagick_outputter'

# http://hamza.khan-cheema.com/show/34-Generate-a-Barcode-in-Ruby-with-Barby-and-a-small-extension
module Barby
  class CustomRmagickOutputter < RmagickOutputter
    register :to_image_with_data
    def to_image_with_data
      # Make canvas  bigger
      canvas = Magick::ImageList.new
      canvas.new_image(full_width , full_height + 10)
      canvas << to_image
      canvas = canvas.flatten_images
      # Make the text
      text = Magick::Draw.new
      text.font_family = 'Helvetica'
      text.pointsize = 12
      text.gravity = Magick::SouthGravity
      text.annotate(canvas , 0,0,0,0, barcode.data)
      canvas
    end
  end
end

class Unit < ActiveRecord::Base
  belongs_to :user
  belongs_to :location
  belongs_to :item
  has_many :logs

  attr_accessible :aquisition_cost, :aquisition_date, :brand, :condition, :is_active, :model, :serial_no, :name
  attr_accessible :barcode_file_name, :item_id, :user_id, :location_id, :logged_in

	has_attached_file :avatar
	has_attached_file :barcode

  validates_presence_of :user_id, :location_id, :item_id, :unless => :new_record?
  after_create :generate_barcode_image

  scope :unassigned, where(:user_id => nil)
  scope :assigned, where("user_id IS NOT NULL")
  scope :active, where(:is_active => true)
  scope :status_in, where(:logged_in => true)
  scope :status_out, where(:logged_in => false)

  def unassigned?
    return true unless self.item_id.present?
    return false
  end
  def status_label
    return "<div class='label label-success'>logged in</div>" if self.logged_in
    return "<div class='label label-important'>logged out</div>"
  end
  def fullname
    return "#{self.id} #{self.name}(#{self.item.name} #{self.brand} #{self.model})"
  end
  # toggle status and create new log
  def toggle(user)
    self.update_attribute(:logged_in, !self.logged_in)
    Log.create(:unit_id => self.id, :user_id => user.id, :status => self.logged_in)
  end
protected
  def generate_barcode_image
	  path = Rails.root.to_s + '/public/system/barcode_images/cgi'
    Dir.mkdir(path) unless File.exists?(path)
	  fname = path + "/#{CGI.escape self.id.to_s}.png"
	  barcode = Barby::Code128B.new self.id
	  outputter = barcode.outputter_for(:to_image_with_data)
	  outputter.height = 55

	  if outputter.to_image_with_data.write(fname)
	    self.barcode = File.new(fname)
	    return self.save(:validate => false)
    else
      return false
    end

  end
end

