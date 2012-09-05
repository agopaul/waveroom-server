require 'rack/contrib'
require File.join(File.dirname(__FILE__), 'waveroom')

use Rack::Evil

run WaveRoom

# Run with: ruby waveroom.rb -p 6874