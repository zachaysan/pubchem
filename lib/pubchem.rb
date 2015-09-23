require 'mechanize'
require_relative 'pubchem/reader'

class Pubchem

  attr_accessor :agent

  def initialize(agent=nil)

    @agent = agent
    @agent ||= Mechanize.new { |agent|
      agent.follow_meta_refresh = true
    }

  end

  def get_ids(ids,
              filename,
              db: :compound,
              retrieve_mode: :image,
              delay: nil)

    ids = ids.join(",") if ids.is_a? Array
    filename = File.expand_path(filename)

    @agent.get('https://pubchem.ncbi.nlm.nih.gov/pc_fetch/pc_fetch.cgi') do |page|

      response = page.form() do |form|

        form.idstr = ids
        form.retmode = retrieve_mode.to_s
        form.db = "pc#{db}"
        button = form.buttons.select { |b| b.value == "Download" }.first
      end.submit

      ftp_link = response.links.select {|l| l.uri.scheme == "ftp"}.first

      while not ftp_link
        delay ||= 0.875 + rand / 2
        sleep(delay)

        reqid_link = response.links.select {|l| l.to_s.start_with? "pc_fetch.cgi?reqid" }.first
        response = @agent.get(reqid_link)
        ftp_link = response.links.select {|l| l.uri.scheme == "ftp"}.first

      end

      ftp_url = ftp_link.to_s
      size = ftp_url.size

      # We don't want to allow scary characters into our URL since it is a
      # security risk, so we only allow lower and upper case letters, numbers,
      # /   forward slashes
      # :   colons
      # .   periods
      # -   dashes
      ftp_url.gsub!(/[^a-zA-Z0-9\/\:\.\-]/u,'')
      raise "Invalid character detected" if ftp_url.size != size

      system("wget", ftp_url, "-O", filename)

    end
  end
end
