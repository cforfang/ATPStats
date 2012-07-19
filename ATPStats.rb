
# Script to fetch player-MatchFact-stats from ATPWorldTour.com, change it to be per-game
# where possible (if requested), and print it.
# See bottom of file for example usage.

# Uses Nokogiri to scrape the data from ATPWorldTour.com

# Copyright (c) 2012 Christian Forfang
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'open-uri'
require 'nokogiri'

module ATPStats
  
  # The "year" for career-stats
  CAREER = 0

  # The different searchable surfaces
  ALL   = 0
  CLAY  = 1
  GRASS = 2
  HARD  = 3

  module Urls
    class << self
      # Returns the ATPWorldTour.com-MatchFacts-URL for "non-top" players
      #   for the given player, surface and year
      def _get_normal_player_url(player, surface, year)
        firstname = player.split[0]
        lastname = player.split[-1]
        enc_player = player.tr(' ', '-')
        enc_surface = surface
        enc_year = year
        url = "http://www.atpworldtour.com/Tennis/Players/#{lastname[0..1]}/#{firstname[0]}/#{enc_player}.aspx?t=mf&y=#{enc_year}&s=#{enc_surface}"
        return url
      end

      # Returns the ATPWorldTour.com-MatchFacts-URL for "top-players"
      #   for the given player, surface and year
      def _get_top_player_url(player, surface, year)
        enc_player = player.tr(" ", "-")
        enc_surface = surface
        enc_year = year
        url = "http://www.atpworldtour.com/Tennis/Players/Top-Players/#{enc_player}.aspx?t=mf&y=#{enc_year}&s=#{enc_surface}"
        return url
      end

      # Returns a list of possible ATPWorldTour.com-MatchFacts-URLs 
      #   for the given player, surface and year
      def get_possible_urls(player, surface, year)
        [
          _get_top_player_url(player, surface, year), # Top-player-URL
          _get_normal_player_url(player, surface, year) # Non-top-player-URL
          # Add more possible URLs if found
        ]
      end
    end #end class << self
  end # end module Urls

  class << self 

    #############
    # "Private" utility methods
    #############

    # Takes a hash with stats and a key which denotes how many games were played
    # The non-percentage stats are then adjusted to be per-game
    # Input and output values in the hash should be strings
    def _convert_stats(stats, games_key)
      new_stats = {}
      games_played = stats[games_key].to_f

      stats.each do |stat_name, value|
        # Process all stats except the 
        # number-of-games-stat and percentage-stats
        unless stat_name == games_key or value.include?("%")
          # Conver to be per-game by dividing by numer of games
          value = (value.to_f / games_played).round(2).to_s
          stat_name = "#{stat_name}/game"
        end
        # Insert into return-hash
        new_stats[stat_name] = value;
      end

      return new_stats
    end

    # Prints stats for two players in columns
    def _printStatsCompare(stats1, stats2, player1_name, player2_name, stats_name)
      col1_size = stats1.keys.max { |a, b| a.length <=> b.length }.length
      col2_size = [stats1.values.max { |a, b| a.length <=> b.length }.length, player1_name.length].max

      printf "\n%-#{col1_size}s %-#{col2_size }s   %s\n", stats_name, player1_name, player2_name
      stats1.keys.each do |key|
        printf "%-#{col1_size}s %-#{col2_size }s   %s\n", key, stats1[key], stats2[key]
      end 
    end

    # Parse the given Nokogiri::HTML::Document for the given stats and return them in a "string => string"-hash
    # Stats-types are :service or :return
    def _parse_document(doc, stats_type)
      # Different selector for service/return-data:
      #   The service-data has class bioMatchfactsCol
      #   while the return-data additionally has class bioMatchfactsCol2
      #   so we select on this.
      #   The stats themselves are in <li>-s.
      data = case stats_type
             when :service then doc.css('div.bioMatchfactsCol:not(.bioMatchfactsCol2) li')
             when :return  then doc.css('div.bioMatchfactsCol2 li')
             else return {}
      end

      stats = {}
      # Parse out stats
      data.each do |li|
        # |li| is on the form <li><span>142</span>Aces</li>
        value = li.children[0].text # Stat-name ("142")
        name  = li.children[1].text # Stat-value ("Aces")
        stats[name] = value
      end
      return stats
    end

    #############
    # "Public" methods
    #############

    # Takes stats in ATPWorldTour-MatchFacts's format and returns them adjusted
    # to be per-game-stats where applicable.
    def convert_to_per_game_stats(service_stats, return_stats)
      # These keys contains the number of games
      service_games_key = 'Service Games Played'
      return_games_key  = 'Return Games Played'

      return {}, {} unless service_stats.has_key?(service_games_key)
      return {}, {} unless  return_stats.has_key?(return_games_key)

      new_service_record = _convert_stats(service_stats, service_games_key)
      new_return_record  = _convert_stats(return_stats,  return_games_key)

      return new_service_record, new_return_record
    end

    # Returns two hashes -- one with service-stats and the other with return-stats.
    # Keys are stat-names and values are the stats-values. 
    # Both are strings.
    def get_ATP_stats(player, surface = ATPStats::ALL, year = ATPStats::CAREER)
      # Get possible URLs where stats are located
      urls = Urls.get_possible_urls(player, surface, year)

      # Make sure to try all URLs before giving up locating data
      max_tries = urls.length
      tries = 0

      # Try each URL in turn until sucessfull or none left
      begin
        try_url = urls[tries]
        puts "Debug: Trying URL #{try_url}"
        doc = Nokogiri::HTML(open(try_url))
      rescue OpenURI::HTTPError
        # On excpetion, try the next URL in the list until we run out
        tries += 1
        if tries < max_tries
          puts 'Debug: Could not locate player at URL. Trying next in list...'
          retry
        else
          puts 'Debug: Failed to locate player page.'
          return {}, {}
        end
      end

      puts 'Debug: Player-page found.'

      # Parse the page for data
      service_stats = _parse_document(doc, :service)
      return_stats  = _parse_document(doc, :return)

      return service_stats, return_stats
    end

    # Tries to fetch data for both players and print it in a nice format
    def compare(player1, player2, 
                surface = ATPStats::ALL, year = ATPStats::CAREER, perGameStats = true)
      p1s, p1r = get_ATP_stats(player1, surface, year)
      p2s, p2r = get_ATP_stats(player2, surface, year)

      if p1s.empty? or p2s.empty? 
        puts 'Unable to get stats for one or both player. Exiting.'
        return
      end

      # Try to convert to per-game stats if requested
      if perGameStats 
        new_p1s, new_p1r = convert_to_per_game_stats(p1s, p1r)
        new_p2s, new_p2r = convert_to_per_game_stats(p2s, p2r)

        if new_p1s.empty? or new_p2s.empty? 
          puts 'Debug: Failed to convert stats. Maybe the game-number-key has changed?'
        else
          p1s = new_p1s
          p1r = new_p1r
          p2s = new_p2s
          p2r = new_p2r
        end
      end

      _printStatsCompare(p1s, p2s, player1, player2, 'Serving Stats')
      _printStatsCompare(p1r, p2r, player1, player2, 'Return Stats')
    end
  end #end class << self
end #end module ATPStats

# If run as a script
if __FILE__ == $0
  # Really basic command-line support.
  # I usually run it from my IDE and change the variables further down.
  # Sample usage: 
  #   ruby ATPStats.rb "Roger Federer" "Novak Djokovic" 2012 grass
  player1 = ARGV[0]
  player2 = ARGV[1]
  year    = ARGV[2].to_i unless ARGV[2].nil?
  surface = case ARGV[3]
            when "hard"  then ATPStats::HARD
            when "grass" then ATPStats::GRASS
            when "clay"  then ATPStats::CLAY
            else ATPStats::ALL
            end
  perGameStats = case ARGV[4]
                 when "false" then false
                 else true
                 end

  player1 ||= 'Roger Federer'
  player2 ||= 'Tommy Haas'
  year    ||= 2012
  surface ||= ATPStats::ALL
  perGameStats = true unless not perGameStats.nil?
  
  puts "Looking up #{player1} and #{player2} in year #{year} on surface \##{surface}.\n"
  ATPStats.compare(player1, player2, surface, year, perGameStats)
end