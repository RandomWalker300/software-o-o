require 'open-uri'
require 'zlib'

class Appdata

  def self.logger
    Rails.logger
  end

  def self.get dist = "factory"
    data = Hash.new
    xml = Appdata.get_distribution dist, "oss"
    data = add_appdata data, xml
    xml = Appdata.get_distribution dist, "non-oss"
    data = add_appdata data, xml
    logger.debug("found #{data[:apps].size} apps")
    data
  end

  private

  def self.add_appdata data, xml
    data[:apps] = Array.new unless data[:apps]
    data[:categories] = Array.new unless data[:categories]
    xml.xpath("/components/component").each do |app|
      appdata = Hash.new
      # Filter translated versions of name and summary out
      appdata[:name] = app.xpath('name[not(@xml:lang)]').text
      appdata[:summary] = app.xpath('summary[not(@xml:lang)]').text
      appdata[:pkgname] = app.xpath('pkgname').text
      appdata[:categories] = app.xpath('categories/category').map{|c| c.text}.reject{|c| c.match(/^X-/)}.uniq
      appdata[:homepage] = app.xpath('url').text
      appdata[:screenshots] = app.xpath('screenshots/screenshot/image').map{|s| s.text}
      data[:apps] << appdata
    end
    data[:categories] += xml.xpath("/components/component/categories/category").
      map{|cat| cat.text}.reject{|c| c.match(/^X-/)}.uniq
    data
  end

  # Get the appdata xml for a distribution
  def self.get_distribution dist = "factory", flavour = "oss"
    appdata_url = if dist == "factory"
                    "http://download.opensuse.org/tumbleweed/repo/#{flavour}/suse/setup/descr/appdata.xml.gz"
                  else
                    "http://download.opensuse.org/distribution/#{dist}/repo/#{flavour}/suse/setup/descr/appdata.xml.gz"
                  end
    logger.debug("fetching appdata for #{dist}/#{flavour}")
    filename = File.join(Rails.root.join('tmp'), "appdata-#{dist}-#{flavour}.xml")
    open(filename, 'wb') do |file|
      # Gzip data will NOT be automatically decompressed with open-uri
      # must have changed at some point in time, so decompress explicitly
      file << Zlib::GzipReader.new(open(appdata_url)).read
    end
    xmlfile = File.open(filename)
    doc = Nokogiri::XML(xmlfile)
    xmlfile.close
    doc
  end

end
