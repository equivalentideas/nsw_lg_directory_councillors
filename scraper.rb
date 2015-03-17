#!/usr/bin/env ruby
require "mechanize"
require "scraperwiki"

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

# Strip "Clr" from the beginning of name
def simplify_name(text)
  if text.split(" ")[0] == "Clr"
    text.split(" ")[1..-1].join(" ")
  else
    text
  end
end

def parse_council(text)
  count = 0
  name = text.lines[0].strip
  # Skip over contact fields like phone, email, etc...
  area_line_no = 3
  while ["P", "E", "W", "DX"].include? text.lines[area_line_no].split("\t").first
    area_line_no += 1
  end
  if text.lines[area_line_no + 4] =~ /Councillors \((\d+)\)/
    no_councillors = $1.to_i
  else
    raise "Unexpected format for number of councillors line"
  end
  if text.lines[area_line_no + 5].split("\t")[0] == "Mayor"
    ScraperWiki.save_sqlite(["councillor", "council"], {
      "councillor" => simplify_name(text.lines[area_line_no + 5].split("\t")[1].strip),
      "position" => "mayor",
      "council" => name})
    count += 1
  else
    puts "Unexpected format for mayor line in #{name}"
  end
  if text.lines[area_line_no + 6].split("\t")[0] == "Deputy"
    ScraperWiki.save_sqlite(["councillor", "council"], {
      "councillor" => simplify_name(text.lines[area_line_no + 6].split("\t")[1].strip),
      "position" => "deputy mayor",
      "council" => name})
    count += 1
  else
    raise "Unexpected format for deputy mayor line"
  end
  text.lines[area_line_no + 7].split(",").each do |t|
    ScraperWiki.save_sqlite(["councillor", "council"], {
      "councillor" => simplify_name(t.strip),
      "council" => name})
    count += 1
  end
  # Do a sanity check
  puts "Councillor numbers not consistent for #{name}" unless count == no_councillors
end

# Find the line "COUNTY COUNCIL"
start_line = data.lines.find_index{|l| l =~ /GENERAL PURPOSE COUNCILS/} + 3
end_line = data.lines.find_index{|l| l =~ /COUNTY COUNCIL/} - 3

# Skip first 6 lines
# And split into each council on double blank line
blocks = data.lines[start_line..end_line].join.split("\r\n\r\n\r\n")

blocks.each do |t|
  parse_council(t)
end
