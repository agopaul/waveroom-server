require 'rubygems'
require 'sinatra'
require 'sinatra/streaming'
require 'json'
require 'yaml'

class WaveRoom < Sinatra::Base

	helpers Sinatra::Streaming

	configure do
		mime_type :json, 'application/json'
		mime_type :mp3, 'audio/mpeg'
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

		content_type :mp3

		start = 0 # unless not params[:start].nil?

		filepath = @folders[id.to_i]+"/"+file
		size = File.size(filepath)

		logger.info "Streaming file: #{file} (#{size} bytes)"
		logger.info "Seeking to #{params[:start]}.. Not yet implemented" unless params[:start].nil?

		# Open file
		file = File.new(filepath, "rb")

		file.seek(start)
		chuck_size = 150*1024 # 40KB

		stream(:keep_open) do |out|

			while chuck = file.read(chuck_size)

				# Wait until connection il ready
				while out.closed?
					logger.info "Closed, sleeping for 3sec"
					sleep 3
				end

				out.write chuck

				# Calculate position in total file
				pos = Float(out.pos)
				size = Float(size)
				percent = (pos/size)*100.0

				logger.info "Sent some bytes (#{pos.to_i}/#{size.to_i}), so far #{percent.to_i}%"
				sleep 3
			end

			logger.info "All the file was streamed to the device"
		end
		
	end

	# todo!
	get '/random' do

		logger.info "Picking random file..."

		[{
			'path' => file
		}].to_json
	end

end