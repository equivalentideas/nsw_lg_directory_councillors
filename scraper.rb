#!/usr/bin/env ruby
require "mechanize"

agent = Mechanize.new
if File.exists?("data.txt")
  puts "Reading from cache..."
  data = File.read("data.txt")
else
  puts "Reading from website..."
  data = agent.get("http://www.olg.nsw.gov.au/sites/default/files/lgdfull.txt").body
  File.open("data.txt", "w") do |f|
    f << data
  end
end

puts data
