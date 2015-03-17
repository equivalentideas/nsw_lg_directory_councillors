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

def parse_council(text)
  p text
  record = {councillors: []}
  record[:name] = text.lines[0].strip
  if text.lines[10] =~ /Councillors \((\d+)\)/
    record[:no_councillors] = $1.to_i
  else
    raise "Unexpected format for number of councillors line"
  end
  if text.lines[11].split("\t")[0] == "Mayor"
    record[:councillors] << {name: text.lines[11].split("\t")[1].strip, position: "mayor"}
  else
    raise "Unexpected format for mayor line"
  end
  if text.lines[12].split("\t")[0] == "Deputy"
    record[:councillors] << {name: text.lines[12].split("\t")[1].strip, position: "deputy mayor"}
  else
    raise "Unexpected format for deputy mayor line"
  end
  text.lines[13].split(",").each do |t|
    record[:councillors] << {name: t.strip, position: "councillor"}
  end
  # Do a sanity check
  raise "Councillor numbers not consistent" unless record[:councillors].count == record[:no_councillors]
  record.delete(:no_councillors)
  record
end

# Skip first 6 lines
# And split into each council on double blank line

p parse_council(data.lines[6..-1].join.split("\r\n\r\n\r\n")[0])
