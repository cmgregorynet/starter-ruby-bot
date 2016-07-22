require 'nokogiri'
require 'open-uri'

class StreetScraper
  URL = "http://www.geographic.org/streetview/usa/ca/san_francisco.html"

  def initialize
    @street_names = []
  end

  def get_street_names
    page = Nokogiri::HTML(open(URL))
    streets = page.css("li a")
    streets.each do |street|
      @street_names << street.text
    end
  end

  def create_channels(num_channels, web_client)
    (1..num_channels).each do
      index = rand(@street_names.length-1)
      street_name = @street_names[index]
      web_client.channels_join(name: street_name)

    end
  end
end