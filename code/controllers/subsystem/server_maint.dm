#define PING_BUFFER_TIME 25

SUBSYSTEM_DEF(server_maint)
	name = "Server Tasks"
	wait = 6
	flags = SS_POST_FIRE_TIMING
	priority = FIRE_PRIORITY_SERVER_MAINT
	init_order = INIT_ORDER_SERVER_MAINT
	init_stage = INITSTAGE_EARLY
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	var/list/currentrun
	var/cleanup_ticker = 0

/datum/controller/subsystem/server_maint/PreInit()
	world.hub_password = "" //quickly! before the hubbies see us.

/datum/controller/subsystem/server_maint/Initialize(timeofday)
	if (CONFIG_GET(flag/hub))
		world.update_hub_visibility(TRUE)
	return ..()

/datum/controller/subsystem/server_maint/fire(resumed = FALSE)
	if(!resumed)
		if(listclearnulls(GLOB.clients))
			log_world("Found a null in clients list!")
		src.currentrun = GLOB.clients.Copy()

		switch (cleanup_ticker) // do only one of these at a time, once per 5 fires
			if (0)
				if(listclearnulls(GLOB.player_list))
					log_world("Found a null in player_list!")
				cleanup_ticker++
			if (5)
				if(listclearnulls(GLOB.mob_list))
					log_world("Found a null in mob_list!")
				cleanup_ticker++
			if (10)
				if(listclearnulls(GLOB.alive_mob_list))
					log_world("Found a null in alive_mob_list!")
				cleanup_ticker++
			if (15)
				if(listclearnulls(GLOB.dead_mob_list))
					log_world("Found a null in dead_mob_list!")
				cleanup_ticker++
			if (20)
				cleanup_ticker = 0
			else
				cleanup_ticker++

	var/list/currentrun = src.currentrun
	var/round_started = SSticker.HasRoundStarted()

	var/kick_inactive = CONFIG_GET(flag/kick_inactive)
	var/afk_period = CONFIG_GET(number/afk_period)
	for(var/client/C as anything in currentrun)
		if(!C)
			continue
		if(C.is_afk() && (world.time - C.inactivity) > C.last_seen_afk)
			SEND_SIGNAL(C.mob, COMSIG_MOB_GO_INACTIVE)
			C.last_seen_afk = world.time

		//handle kicking inactive players
		if(round_started && kick_inactive && !C.holder && C.is_afk(afk_period))
			var/mob/cmob = C.mob
			if(!isnewplayer(cmob) || !SSticker.queued_players.Find(cmob))
				log_access("AFK: [key_name(C)]")
				to_chat(C, span_userdanger("You have been inactive for more than [DisplayTimeText(afk_period)] and have been disconnected.</span><br><span class='danger'>You may reconnect via the button in the file menu or by <b><u><a href='byond://winset?command=.reconnect'>clicking here to reconnect</a></u></b>."))
				QDEL_IN(C, 1) //to ensure they get our message before getting disconnected
				continue

		if (!(!C || world.time - C.connection_time < PING_BUFFER_TIME || C.inactivity >= (wait-1)))
			winset(C, null, "command=.update_ping+[world.time+world.tick_lag*TICK_USAGE_REAL/100]")

		if (MC_TICK_CHECK) //one day, when ss13 has 1000 people per server, you guys are gonna be glad I added this tick check
			return

/datum/controller/subsystem/server_maint/Shutdown()
	kick_clients_in_lobby(span_boldannounce("The round came to an end with you in the lobby."), TRUE) //second parameter ensures only afk clients are kicked
	var/server = CONFIG_GET(string/server)
	for(var/thing in GLOB.clients)
		if(!thing)
			continue
		var/client/C = thing
		C?.tgui_panel?.send_roundrestart()
		if(server)	//if you set a server location in config.txt, it sends you there instead of trying to reconnect to the same world address. -- NeoFite
			C << link("byond://[server]")
	var/datum/tgs_version/tgsversion = world.TgsVersion()
	if(tgsversion)
		SSblackbox.record_feedback("text", "server_tools", 1, tgsversion.raw_parameter)


/datum/controller/subsystem/server_maint/proc/UpdateHubStatus()
	if(!CONFIG_GET(flag/hub) || !CONFIG_GET(number/max_hub_pop))
		return FALSE //no point, hub / auto hub controls are disabled

	var/max_pop = CONFIG_GET(number/max_hub_pop)

	if(GLOB.clients.len > max_pop)
		world.update_hub_visibility(FALSE)
	else
		world.update_hub_visibility(TRUE)
#undef PING_BUFFER_TIME
