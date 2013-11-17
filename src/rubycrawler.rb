=begin
  
© Nikita Chong 2013

10/05/2013

v5 of a Web-Crawling Search Engine POC. 

=end

#!/usr/bin/env ruby

require 'nokogiri'
require 'pp'
require 'open-uri'
require 'certified' # install this gem to prevent OpenSSL problems
require 'csv'
require 'set'

# Given a URL, return all links on the page in an array.
# e.g. depth 1 = links on first page only
# depth 2 = links on first page, crawl all links on those pages and return the links 
def scrape_page(url) 
    puts "Scraping " + url + "."
    elements = []
    
    begin
      doc = Nokogiri::HTML(open(url))
      elements = doc.xpath("//a[@href]")
    rescue RuntimeError
      #puts "Runtime error caught"
    rescue OpenURI::HTTPError
      #puts "OpenURI error caught"
    rescue OpenURI::HTTPRedirect 
      #puts "OpenURI redir error caught"
    rescue SocketError
      #puts "SocketError caught"
    end
    
    puts "Number of href elements found: " + elements.length.to_s
    results = []
    elements.each do |link|
      #link = (link.first.to_s.scan(/.+?href=".*"/))  # Replaced by URI::extract!!
      urls = URI::extract(link.to_s)  # extract URL
      if !urls.empty?
        urls.each do |u|  
          if u.include?("http") # don't store links which aren't prefixed with "http"
            results << (u.to_s) # store link
          end
        end
      end
    end
      
  if results.empty? then puts "No links found in " + url + "." end
  
  results.compact.uniq # avoid nils and duplicates
  
end

# Create a csv file to store scraped links. 
# Format is link, y/n (scraped or not)
# Takes in an array of links.
# Returns a set of scraped links.  
def populate_index(scraped)
  # cleanse the collection of scraped links - only keep links beginning with "http"
  filename = "..\\res\\index.csv"
  links = Set.new
  
  puts "Populating index: " + filename
  
  File.new(filename, "w+") unless File.exist?(filename)
  
  if !scraped.empty?
    CSV::open(filename, "wb") do |csv|
      csv << ["URL", "Scraped?"]
      scraped.each do |link| 
        csv << [link, "n"] 
        links.add(link)
      end
    end
  end
  
  links
  
end

# Procedure: Given a link, scrape it for links - USE AS THE SEED.  
# Then scrape those links up to a depth of n. 

def build_index(seed, depth)
  filename = "index.csv"
   
  # if depth is 0, scrape the seed, SET N TO Y, and stop. 
  # if depth is greater than 0, go back to beginning of file
  # scrape each page, mark scraped, and append it to the index
  
  populate_index(scrape_page(seed)) 
  
  # read index, rowid = $.
  # for each, check row[1] for y
  # if !y, scrape and append to index
  
  i = 1
  links = Set.new # AVOID DUPLICATE LINKS IN THE INDEX
  
  while i <= depth
    puts "Scraping at DEPTH: i = #{i}"
    CSV.foreach(filename, :headers => true) do |row|   
      if row[1] != "y" && !links.include?(row[0])
        scrape_page(row[0]).each do |link|  
          if !links.include?(link)  # AVOID DUPLICATE LINKS IN THE INDEX 
            links.add(link)
            CSV::open(filename, "ab") do |csv|
              csv << [link, "n"]
            end
          end
        end
        row[1] << "y" #doesn't work? can probably get rid of. 
      end
    end
    i+=1
  end
  
  # index complete
  
end

# Search engine menthod. Search for a term in the index. 
def search_index(filename, term)
  puts "Searching for the term: " + term
  CSV.foreach(filename, :headers => true) do |row|
    
    begin
      doc = Nokogiri::HTML(open(row[0]))
      pagetext  = doc.at('body').inner_text
      # Pretend that all words we care about contain only a-z, 0-9, or underscores
      if pagetext.scan(/\w+/).include?(term) then puts "Result: " + row[0] else puts row[0] + " does not include " + term end
    rescue RuntimeError
      #puts "Runtime error caught"
    rescue OpenURI::HTTPError
      #puts "OpenURI error caught"
    rescue OpenURI::HTTPRedirect 
      #puts "OpenURI redir error caught"
    end
  end
  
end

puts "\n********v.5 execution********"

page = "https://en.wikipedia.org/wiki/Mark_Keane" 
puts "\n********POPULATING INDEX...********"
populate_index(scrape_page(page))
build_index(page, 1)
puts "\n********SEARCH********"
search_index("index.csv", "fashion")
