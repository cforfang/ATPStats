require_relative "ATPStats"

require "test/unit"
require "nokogiri"

class TestATPStats < Test::Unit::TestCase

	def test_get_normal_player_url
		assert_equal("http://www.atpworldtour.com/Tennis/Players/Ha/T/Tommy-Haas.aspx?t=mf&y=2012&s=0", ATPStats::Urls._get_normal_player_url("Tommy Haas", ATPStats::ALL, 2012))
		assert_equal("http://www.atpworldtour.com/Tennis/Players/Ha/T/Tommy-Haas.aspx?t=mf&y=0&s=3", ATPStats::Urls._get_normal_player_url("Tommy Haas", ATPStats::HARD, 0))
	end

	def test_get_top_player_url
		assert_equal("http://www.atpworldtour.com/Tennis/Players/Top-Players/Novak-Djokovic.aspx?t=mf&y=2012&s=0", ATPStats::Urls._get_top_player_url("Novak Djokovic", ATPStats::ALL, 2012))
	end

	def test_get_possible_urls 
		assert_equal(["http://www.atpworldtour.com/Tennis/Players/Top-Players/Novak-Djokovic.aspx?t=mf&y=2012&s=0","http://www.atpworldtour.com/Tennis/Players/Dj/N/Novak-Djokovic.aspx?t=mf&y=2012&s=0"], ATPStats::Urls.get_possible_urls("Novak Djokovic", ATPStats::ALL, 2012))
	end

	def test_surface_constants
		assert_equal(ATPStats::ALL,   0)
		assert_equal(ATPStats::CLAY,  1)
		assert_equal(ATPStats::GRASS, 2)
		assert_equal(ATPStats::HARD,  3)
	end

	def test_convert_stats
		games_key = "gk"
		stats = {"Percentage-stat" => "100%", games_key => "100", "Depends-on-games-stat" => "50"}

		converted_stats = ATPStats._convert_stats(stats, games_key)

		# Percentage-stats and games-stats untouched
		assert_equal(stats["Percentage-stat"], converted_stats["Percentage-stat"])
		assert_equal(stats[games_key], converted_stats[games_key])

		# Other stats convertd successfully
		assert(converted_stats.has_key? "Depends-on-games-stat/game")
		assert(!converted_stats.has_key?("Depends-on-games-stat"))
		assert_equal(converted_stats["Depends-on-games-stat/game"], (50.0/100).to_s)
	end

	def test_convertToPerGameStats
		# Hashes without the necessary keys
		a, b = ATPStats.convert_to_per_game_stats({}, {})
		assert_equal({}, a)
		assert_equal({}, b)

		# Hashes without the necessary keys
		a, b = ATPStats.convert_to_per_game_stats({:a => "a"}, {"b" => "b"})
		assert_equal({}, a)
		assert_equal({}, b)

		service_games_key = "Service Games Played"
		return_games_key  = "Return Games Played"

		a, b = ATPStats.convert_to_per_game_stats({"Service Games Played" => "a"}, {"b" => "b"})
		assert_equal({}, a)
		assert_equal({}, b)

		a, b = ATPStats.convert_to_per_game_stats({"a" => "a"}, {"Return Games Played" => "b"})
		assert_equal({}, a)
		assert_equal({}, b)

		a, b = ATPStats.convert_to_per_game_stats({"Service Games Played" => "10"}, {"Return Games Played" => "10"})
		assert_not_equal({}, a)
		assert_not_equal({}, b)

		h1 = {"Service Games Played" => "10"}
		h2 =  {"Return Games Played" => "10"}
		a, b = ATPStats.convert_to_per_game_stats(h1, h2)
		assert_equal(a, ATPStats._convert_stats(h1, service_games_key))
		assert_equal(b, ATPStats._convert_stats(h2, return_games_key))
	end

	def test_parse_document
		# Relevant part of 
		#   www.atpworldtour.com/Tennis/Players/Top-Players/Thomaz-Bellucci.aspx?t=mf&y=2012&s=3
		#   as of 18 July 2012
		doc = """
		    <div class=\"bioMatchfactsCol\">
		        <h6>Service Record Year-to-Date:</h6>
		        <ul>
		            <li><span>64</span>Aces</li>
		            <li><span>27</span>Double Faults</li>
		            <li><span>53%</span>1st Serve</li>
		            <li><span>75%</span>1st Serve Points Won</li>
		            <li><span>54%</span>2nd Serve Points Won</li>
		            <li><span>49</span>Break Points Faced</li>
		            <li><span>65%</span>Break Points Saved</li>
		            <li><span>102</span>Service Games Played</li>
		            <li><span>83%</span>Service Games Won</li>
		            <li><span>65%</span>Service Points Won</li>
		        </ul>
		    </div>
		    <div class=\"bioMatchfactsCol bioMatchfactsCol2\">
		        <h6>Return Record Year-to-Date:</h6>
		        <ul>
		            <li><span>30%</span>1st Serve Return Points Won</li>
		            <li><span>48%</span>2nd Serve Return Points Won</li>
		            <li><span>59</span>Break Points Opportunities</li>
		            <li><span>34%</span>Break Points Converted</li>
		            <li><span>103</span>Return Games Played</li>
		            <li><span>19%</span>Return Games Won</li>
		            <li><span>37%</span>Return Points Won</li>
		            <li><span>51%</span>Total Points Won</li>
		        </ul>
		    </div>
			"""
			# Convert the HTML to Nokogiri's format as that's what _parse_document() expects
			doc = Nokogiri::HTML(doc)

			s = {"Aces"=>"64", "Double Faults"=>"27", "1st Serve"=>"53%", "1st Serve Points Won"=>"75%", "2nd Serve Points Won"=>"54%", "Break Points Faced"=>"49", "Break Points Saved"=>"65%", "Service Games Played"=>"102", "Service Games Won"=>"83%", "Service Points Won"=>"65%"}
			r = {"1st Serve Return Points Won"=>"30%", "2nd Serve Return Points Won"=>"48%", "Break Points Opportunities"=>"59", "Break Points Converted"=>"34%", "Return Games Played"=>"103", "Return Games Won"=>"19%", "Return Points Won"=>"37%", "Total Points Won"=>"51%"}

			# Check to see we get back the expected stats
			assert_equal(s, ATPStats._parse_document(doc, :service))
			assert_equal(r, ATPStats._parse_document(doc, :return))
	end
end
