require 'rubygems'
require 'sinatra'
require 'json'

FOLDERS = ["/data/Music", "/data/rtorrent/downloading/whatcd/"]

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
	end

	error do
		str = "error: #{request.env['sinatra.error'].to_s}"
		File.open("log/waveroom_error.log", "a+") do |f|
			f.write "[#{Time.now.to_s}] #{str}\n"
		end
		str
	end

	get	'/folders' do
		content_type :json

		resp = []
		c = 0
		FOLDERS.each do |f|
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

		dir = FOLDERS[id.to_i]
		dir += sec unless sec.nil?

		resp = []

		Dir.foreach(dir) do |file|
			if File.file?(dir+"/"+file) and file =~ /\.mp3$/
				resp.push({
					'type' => 'file',
					'name' => file
				})
			else
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
		# content_type :mp3

		start = 0 # unless not params[:start].nil?

		mp3 = Mp3Stream.new(FOLDERS[id.to_i]+"/"+file, start.to_i)
		throw :response, [200, {'Content-type' => 'audio/mpeg', 'Content-Length' => mp3.length.to_s}, mp3]
		
	end

	# todo!
	get '/random' do
		[{
			'path' => file
		}].to_json
	end

end

