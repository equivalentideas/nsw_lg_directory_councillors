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
  parts = text.split(" ")
  first = 0
  last = -1
  if parts[0] == "Clr"
    first = 1
  end
  if parts[-1] == "elected)"
    last = -3
  end
  parts[first..last].join(" ")
end

def create_id(council, name)
  components = council + "/" + name
  components.downcase.gsub(" ","_")
end

def parse_council(text)
  count = 0
  name = text.lines[0].strip
  # Skip over contact fields like phone, email, etc...
  area_line_no = 3
  while ["P", "E", "W", "DX"].include? text.lines[area_line_no].split("\t").first
    if text.lines[area_line_no].split("\t").first == "W"
      website = text.lines[area_line_no].split("\t")[1].strip
    end
    area_line_no += 1
  end
  if text.lines[area_line_no + 4] =~ /Councillors \((\d+)\)/
    no_councillors = $1.to_i
  else
    raise "Unexpected format for number of councillors line"
  end
  mayor_line = text.lines[area_line_no + 5].split("\t")
  if (mayor_line[0] == "Mayor" or mayor_line[0] == "Lord Mayor") and not mayor_line[1].empty?
    councillor_name = simplify_name(mayor_line[1].strip)
    ScraperWiki.save_sqlite(["councillor", "council_name"], {
      "id" => create_id(name, councillor_name),
      "councillor" => councillor_name,
      "position" => mayor_line[0],
      "council_name" => name,
      "council_website" => website})
    count += 1
  else
    puts "Unexpected format for mayor line in #{name}: #{mayor_line}"
  end
  deputy_line = text.lines[area_line_no + 6].split("\t")
  if deputy_line[0] == "Deputy" and not deputy_line[1].empty?
    councillor_name = simplify_name(deputy_line[1].strip)
    ScraperWiki.save_sqlite(["councillor", "council_name"], {
      "id" => create_id(name, councillor_name),
      "councillor" => councillor_name,
      "position" => "deputy mayor",
      "council_name" => name,
      "council_website" => website})
    count += 1
  else
    raise "Unexpected format for deputy mayor line in #{name}: #{deputy_line}"
  end
  text.lines[area_line_no + 7].split(",").each do |t|
    next if t.strip.empty?
    ScraperWiki.save_sqlite(["councillor", "council_name"], {
      "id" => create_id(name, simplify_name(t.strip)),
      "councillor" => simplify_name(t.strip),
      "council_name" => name,
      "council_website" => website})
    count += 1
  end
  # Do a sanity check
  puts "Councillor numbers not consistent for #{name}: expected #{no_councillors} got #{count}" unless count == no_councillors
end

# Find the line "COUNTY COUNCIL"
start_line = data.lines.find_index{|l| l =~ /GENERAL PURPOSE COUNCILS/} + 3
end_line = data.lines.find_index{|l| l =~ /COUNTY COUNCIL/} - 3

# Skip first 6 lines
# And split into each council on double blank line
blocks = data.lines[start_line..end_line].join.split(/\r?\n\r?\n\r?\n/)

blocks.each do |t|
  parse_council(t)
end
