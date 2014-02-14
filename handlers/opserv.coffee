###
# Chatbot for Tim's Chat 3
# Copyright (C) 2011 - 2014 Tim Düsterhus
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
###

common = require '../common'
config = require '../config'
handlers = require '../handlers'
api = require '../api'
winston = require 'winston'
db = require '../db'

frontend = require '../frontend'

commands = 
	shutdown: (callback) ->
		api.leaveChat ->
			do callback if callback?
			process.exit 0
	load: (callback, parameters) -> handlers.loadHandler parameters, callback
	unload: (callback, parameters) -> handlers.unloadHandler parameters, callback
	loaded: (callback) -> callback handlers.getLoadedHandlers() if callback?

frontend.get '/opserv/shutdown', (req, res) -> commands.shutdown -> res.send 200, 'OK'
frontend.get '/opserv/load/:module', (req, res) -> 
	commands.load (err) -> 
		if err?
			res.send 503, err
		else
			res.send 200, 'OK'
	, req.params.module
frontend.get '/opserv/unload/:module', (req, res) -> 
	commands.unload (err) -> 
		if err?
			res.send 503, err
		else
			res.send 200, 'OK'
	, req.params.module
frontend.get '/opserv/loaded', (req, res) ->
	commands.loaded (handlers) -> res.send 200, handlers.join ', '

handleMessage = (message, callback) ->
	if message.message.substring(0, 1) isnt '?'
		# ignore messages that don't start with a question mark
		do callback if callback?
		return
	
	text = (message.message.substring 1).split /\s/
	[ command, parameters ] = [ text.shift(), text.join ' ' ]
	
	switch command
		when "shutdown"
			db.checkPermissionByMessage message, 'opserv.shutdown', (hasPermission) ->
				if permission
					do commands.shutdown
				else
					do callback if callback?
		when "loaded"
			db.checkAnyPermissionByMessage message, [ 'opserv.load', 'opserv.unload' ], (hasPermission) ->
				if hasPermission
					commands.loaded (handlers) -> api.sendMessage "These handlers are loaded: #{handlers.join ', '}", no, callback
				else
					do callback if callback?
		when "load"
			commands.load (err) ->
				api.replyTo message, (if err? then "Failed to load module #{parameters}" else "Loaded module #{parameters}"), no, callback
			, parameters
		when "unload"
			commands.unload (err) ->
				api.replyTo message, (if err? then "Failed to unload module #{parameters}" else "Unloaded module #{parameters}"), no, callback
			, parameters
		when "setPermission"
			db.checkPermissionByMessage message, 'opserv.setPermission', (hasPermission) ->
				if hasPermission
					[ username, permission... ] = parameters.split /,/
					
					db.getUserByUsername username.trim(), (err, user) ->
						if user?
							db.givePermissionToUserID user.userID, permission.join('').trim(), (rows) ->
								api.replyTo message, "Gave #{permission} to #{username}", no, callback
						else
							api.replyTo message, "Could not find user „#{username}“", no, callback
				else
					# We trust you have received the usual lecture from the local System
					# Administrator. It usually boils down to these three things:
					#
					#    #1) Respect the privacy of others.
					#    #2) Think before you type.
					#    #3) With great power comes great responsibility.
					#
					# This incident will be reported.
					do callback if callback?
		when "getPermissions"
			db.checkAnyPermissionByMessage message, [ 'opserv.setPermission', 'opserv.getPermissions' ], (hasPermission) ->
				if hasPermission
					db.getUserByUsername parameters, (err, user) ->
						if user?
							db.getPermissionsByUserID user.userID, (rows) ->
								api.replyTo message, "#{user.lastUsername} (#{user.userID}) has the following permissions: #{(row.permission for row in rows).join ', '}", no, callback
						else
							api.replyTo message, "Could not find user „#{parameters}“", no, callback
				else
					do callback if callback?
		else
			winston.debug "[OpServ] Ignoring unknown command", command
			do callback if callback?

unload = (callback) ->
	winston.error "panic() - Going nowhere without my opserv"
	process.exit 1

module.exports =
	handleMessage: handleMessage
	handleUser: (user, callback) -> do callback if callback?
	unload: unload
