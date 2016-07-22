require 'nokogiri'

class StreetScraper
  URL = "www.geographic.org/streetview/usa/ca/san_francisco.html"

  def get_street_names
    page = Nokogiri::HTML(open(URL))
    streets = page.css("li a")
    streets.each do |street|
      puts street.text
    end
  end
end