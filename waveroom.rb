require 'rubygems'
require 'sinatra'
require 'json'
require 'yaml'

@folders = ["/data/Music", "/data/rtorrent/downloading/whatcd/"]

class Mp3Stream
	
	def initialize(filename, start_pos)
		@filename, @start_pos = filename, start_pos

		@file = File.new(filename, "rb")
		@file.seek(start_pos)
		@chuck_size = 4*1024
	end

	def each		
		begin chunk = @file.read(@chuck_size)
			yield chunk
		end while chunk.size == @chuck_size
	end

	def length
		File.size(@filename) - @start_pos
	end

end

class WaveRoom < Sinatra::Base

	configure do
		mime_type :json, 'application/json'
		set :logging, true
	end

	error do
		str = "error: #{request.env['sinatra.error'].to_s}"
		
		logger.error error
		str
	end

	before do
		y = YAML.load_file("waveroom.yml")
		@folders = y["folders"]
	end

	get	'/folders' do

		logger.info "Request folder list"
		logger.info "Loaded folders: #{@folders.inspect}"

		content_type :json

		resp = []
		c = 0
		@folders.each do |f|
			resp.push({
				'type' => 'folder',
				'name' => f,
				'id' => c
			})
			c += 1
		end

		resp.to_json
	end

	get	%r{/contents/([\d]+)(/.*)?} do |id, sec|
		content_type :json

		dir = @folders[id.to_i]
		dir += sec unless sec.nil?

		logger.info "Loading file list of folder #{dir}"

		resp = []

		Dir.foreach(dir) do |file|
			# If is a mp3 file
			if File.file?(dir+"/"+file) and file =~ /\.mp3$/
				resp.push({
					'type' => 'file',
					'name' => file
				})
			else
				#or if is a directory
				if File.directory?(dir+"/"+file) and not file =~ /^\./
					resp.push({
						'type' => 'folder',
						'name' => file
					})
				end
			end
		end

		resp.to_json
	end

	get	%r{/file/([\d]+)/(.+)} do |id, file|

		start = 0 # unless not params[:start].nil?

		mp3 = Mp3Stream.new(@folders[id.to_i]+"/"+file, start.to_i)
		size = mp3.length.to_s

		logger.info "Streaming file: #{file} (#{size} bytes)"
		logger.info "Seeking to #{params[:start].inspect}.. Not yet implemented" unless not params[:start].nil?		
		
		throw :response, [200, {'Content-type' => 'audio/mpeg', 'Content-Length' => size}, mp3]
		
	end

	# todo!
	get '/random' do

		logger.info "Picking random file..."

		[{
			'path' => file
		}].to_json
	end

end

