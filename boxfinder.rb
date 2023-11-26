#!/usr/bin/env ruby
#
# boxfinder - box volume matching script
# Copyright (C) 2023  Ingo Korb <ingo@akana.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'csv'
require 'optparse'
require 'pp'

$VERBOSE = true

class Dimensions
  attr_accessor :length
  attr_accessor :width
  attr_accessor :height

  def initialize(length, width, height)
    @length = length
    @width = width
    @height = height
  end

  def area
    @length * @width
  end
  
  def volume
    @length * @width * @height
  end

  def to_s
    return "#{@length} x #{@width} x #{@height}"
  end

  def width_rotated
    return Dimensions.new(@length, @height, @width)
  end

  def length_rotated
    return Dimensions.new(@height, @width, @length)
  end
  
  def fits_into(otherdim, sideways)
    if (otherdim.height == 0 || @height == 0 || @height <= otherdim.height) &&
       ((@length <= otherdim.length && @width  <= otherdim.width) ||
        (@width  <= otherdim.length && @length <= otherdim.width))
      return true
    end

    if sideways
      ret = fits_into(otherdim.width_rotated, false) || fits_into(otherdim.length_rotated, false)
      return ret
    end

    return false
  end

  def fits_over(otherdim, sideways)
    if (otherdim.height == 0 || @height == 0 || @height >= otherdim.height) &&
       ((@length >= otherdim.length && @width >= otherdim.width) ||
        (@width >= otherdim.length && @length >= otherdim.width))
      return true
    end

    if sideways
      return fits_over(otherdim.width_rotated, false) || fits_over(otherdim.length_rotated, false)
    end

    return false
  end
end

class Boxsize
  attr_accessor :name
  attr_accessor :dimensions

  def initialize(name, dims)
    @name = name
    @dimensions = dims
  end

  def to_s
    return "#{@name}: #{@dimensions}"
  end
end

def parseDimensions(str)
  dims = str.split("x")
  if dims.size != 3
    $stderr.puts "ERROR: unparseable dimension \"#{str}\""
    exit 2
  end
  length = dims[0].to_i(10)
  width = dims[1].to_i(10)
  height = dims[2].to_i(10)
  return Dimensions.new(length, width, height)
end


options = { :boxfile => File.dirname(__FILE__) + "/boxes.tsv",
            :fitmode => :over,
            :sideways => false,
            :numresults => 5
          }

parser = OptionParser.new do |opts|
  opts.banner = "Usage: boxfinder.rb [options] length width [height]"

  opts.on("-bNAME", "--boxfile=NAME", "specify box data CSV file") do |boxfile|
    options[:boxfile] = boxfile
  end

  opts.on("-i", "--into", "fit box into given dimensions") do
    options[:fitmode] = :into
  end

  opts.on("-o", "--over", "fit box over given dimensions") do
    options[:fitmode] = :over
  end

  opts.on("-s", "--sideways", "allow turning box on its side") do
    options[:sideways] = true
  end

  opts.on("-nNUM", "--results=NUM", "show NUM best matches") do |num|
    options[:numresults] = num.to_i
  end

  opts.on_tail("-h", "--help", "Prints this help") do
    puts opts
    exit 0
  end
end
parser.parse!

if ARGV.length < 2 || ARGV.length > 3
  puts parser.help
  exit 1
end

Boxes = []

File.open(options[:boxfile], "r") do |fd|
  boxdata = CSV.new(fd, :col_sep => "\t")
  boxdata.each do |row|
    if row.length < 3
      next
    end

    if row[0].start_with?("#")
      next
    end

    name = row[0].strip
    outerdim = parseDimensions(row[1])
    if row[2].strip == "-"
      innerdim = outerdim
    else
      innerdim = parseDimensions(row[2])
    end

    if options[:fitmode] == :over
      Boxes.append(Boxsize.new(name, innerdim))
    else
      Boxes.append(Boxsize.new(name, outerdim))
    end
  end
end

fitting_boxes = []
length = ARGV[0].to_i
width = ARGV[1].to_i
height = 0
if ARGV.size > 2
  height = ARGV[2].to_i
end
target = Dimensions.new(length, width, height)

if options[:sideways] && height == 0
  $stderr.puts "ERROR: Height must be specified for sideways mode"
  exit 2
end

Boxes.each do |box|
  result = false
  if options[:fitmode] == :over
    result = box.dimensions.fits_over(target, options[:sideways])
  else
    result = box.dimensions.fits_into(target, options[:sideways])
  end

  fitting_boxes.append(box) if result
end

if target.height != 0
  fitting_boxes.sort! do |a, b|
    a.dimensions.volume <=> b.dimensions.volume
  end
else
  fitting_boxes.sort! do |a, b|
    (a.dimensions.length * a.dimensions.width) <=> (b.dimensions.length * b.dimensions.width)
  end
end

if options[:fitmode] == :into
  fitting_boxes.reverse!
end

outputset = fitting_boxes[0..(options[:numresults] - 1)]
maxname = outputset.map { |box| box.name.size }.max
maxdim = outputset.map { |box| box.dimensions.to_s.size }.max

outputset.each_with_index do |box, i|
  if target.height == 0
    pct = target.area.to_f / box.dimensions.area
  else
    pct = box.dimensions.volume.to_f / target.volume
  end

  if options[:fitmode] == :over
    pct = 1 / pct
  end

  printf "%*d. %*s - %*s (%5.2f%%)\n",
         Math.log10(options[:numresults]) + 1, i+1,
         -maxname, box.name,
         maxdim, box.dimensions, pct * 100
end
