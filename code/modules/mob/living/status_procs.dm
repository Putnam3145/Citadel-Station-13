//Here are the procs used to modify status effects of a mob.
//The effects include: stun, knockdown, unconscious, sleeping, resting, jitteriness, dizziness,
// eye damage, eye_blind, eye_blurry, druggy, TRAIT_BLIND trait, and TRAIT_NEARSIGHT trait.


////////////////////////////// STUN ////////////////////////////////////

/mob/living/IsStun() //If we're stunned
	return has_status_effect(STATUS_EFFECT_STUN)

/mob/living/proc/AmountStun() //How many deciseconds remain in our stun
	var/datum/status_effect/incapacitating/stun/S = IsStun()
	if(S)
		return S.duration - world.time
	return 0

/mob/living/proc/Stun(amount, updating = TRUE, ignore_canstun = FALSE) //Can't go below remaining duration
	if(((status_flags & CANSTUN) && !HAS_TRAIT(src, TRAIT_STUNIMMUNE)) || ignore_canstun)
		if(absorb_stun(amount, ignore_canstun))
			return
		var/datum/status_effect/incapacitating/stun/S = IsStun()
		if(S)
			S.duration = max(world.time + amount, S.duration)
		else if(amount > 0)
			S = apply_status_effect(STATUS_EFFECT_STUN, amount, updating)
		return S

/mob/living/proc/SetStun(amount, updating = TRUE, ignore_canstun = FALSE) //Sets remaining duration
	if(((status_flags & CANSTUN) && !HAS_TRAIT(src, TRAIT_STUNIMMUNE)) || ignore_canstun)
		var/datum/status_effect/incapacitating/stun/S = IsStun()
		if(amount <= 0)
			if(S)
				qdel(S)
		else
			if(absorb_stun(amount, ignore_canstun))
				return
			if(S)
				S.duration = world.time + amount
			else
				S = apply_status_effect(STATUS_EFFECT_STUN, amount, updating)
		return S

/mob/living/proc/AdjustStun(amount, updating = TRUE, ignore_canstun = FALSE) //Adds to remaining duration
	if(((status_flags & CANSTUN) && !HAS_TRAIT(src, TRAIT_STUNIMMUNE)) || ignore_canstun)
		if(absorb_stun(amount, ignore_canstun))
			return
		var/datum/status_effect/incapacitating/stun/S = IsStun()
		if(S)
			S.duration += amount
		else if(amount > 0)
			S = apply_status_effect(STATUS_EFFECT_STUN, amount, updating)
		return S

///////////////////////////////// KNOCKDOWN /////////////////////////////////////

/mob/living/IsKnockdown() //If we're knocked down
	var/health_deficiency = max((maxHealth - (health - getStaminaLoss()))*0.5, 0)
	return IsStun() || (health_deficiency > 35 && resting)

/mob/living/proc/Knockdown(amount, updating = TRUE, ignore_canknockdown = FALSE, override_hardstun, override_stamdmg) //Can't go below remaining duration
	if(((status_flags & CANKNOCKDOWN) && !HAS_TRAIT(src, TRAIT_STUNIMMUNE)) || ignore_canknockdown)
		if(absorb_stun(isnull(override_hardstun)? amount : override_hardstun, ignore_canknockdown))
			return
		if(istype(buckled, /obj/vehicle/ridden))
			var/obj/buckl = buckled
			buckl.unbuckle_mob(src)
		resting = TRUE
		adjustStaminaLoss(isnull(override_stamdmg)? amount*0.25 : override_stamdmg)
		if(!isnull(override_hardstun))
			Stun(override_hardstun,updating,ignore_canknockdown)
		if(updating)
			update_canmove()
		return TRUE

///////////////////////////////// FROZEN /////////////////////////////////////

/mob/living/proc/IsFrozen()
	return has_status_effect(/datum/status_effect/freon)

///////////////////////////////////// STUN ABSORPTION /////////////////////////////////////

/mob/living/proc/add_stun_absorption(key, duration, priority, message, self_message, examine_message)
//adds a stun absorption with a key, a duration in deciseconds, its priority, and the messages it makes when you're stun/examined, if any
	if(!islist(stun_absorption))
		stun_absorption = list()
	if(stun_absorption[key])
		stun_absorption[key]["end_time"] = world.time + duration
		stun_absorption[key]["priority"] = priority
		stun_absorption[key]["stuns_absorbed"] = 0
	else
		stun_absorption[key] = list("end_time" = world.time + duration, "priority" = priority, "stuns_absorbed" = 0, \
		"visible_message" = message, "self_message" = self_message, "examine_message" = examine_message)

/mob/living/proc/absorb_stun(amount, ignoring_flag_presence)
	if(!amount || amount <= 0 || stat || ignoring_flag_presence || !islist(stun_absorption))
		return FALSE
	var/priority_absorb_key
	var/highest_priority
	for(var/i in stun_absorption)
		if(stun_absorption[i]["end_time"] > world.time && (!priority_absorb_key || stun_absorption[i]["priority"] > highest_priority))
			priority_absorb_key = stun_absorption[i]
			highest_priority = priority_absorb_key["priority"]
	if(priority_absorb_key)
		if(priority_absorb_key["visible_message"] || priority_absorb_key["self_message"])
			if(priority_absorb_key["visible_message"] && priority_absorb_key["self_message"])
				visible_message("<span class='warning'>[src][priority_absorb_key["visible_message"]]</span>", "<span class='boldwarning'>[priority_absorb_key["self_message"]]</span>")
			else if(priority_absorb_key["visible_message"])
				visible_message("<span class='warning'>[src][priority_absorb_key["visible_message"]]</span>")
			else if(priority_absorb_key["self_message"])
				to_chat(src, "<span class='boldwarning'>[priority_absorb_key["self_message"]]</span>")
		priority_absorb_key["stuns_absorbed"] += amount
		return TRUE

/////////////////////////////////// DISABILITIES ////////////////////////////////////

/mob/living/proc/add_quirk(quirk, spawn_effects) //separate proc due to the way these ones are handled
	if(HAS_TRAIT(src, quirk))
		return
	if(!SSquirks || !SSquirks.quirks[quirk])
		return
	var/datum/quirk/T = SSquirks.quirks[quirk]
	new T (src, spawn_effects)
	return TRUE

/mob/living/proc/remove_quirk(quirk)
	var/datum/quirk/T = roundstart_quirks[quirk]
	if(T)
		qdel(T)
		return TRUE

/mob/living/proc/has_quirk(quirk)
	return roundstart_quirks[quirk]

/////////////////////////////////// TRAIT PROCS ////////////////////////////////////

/mob/living/proc/cure_blind(list/sources)
	REMOVE_TRAIT(src, TRAIT_BLIND, sources)
	if(!HAS_TRAIT(src, TRAIT_BLIND))
		adjust_blindness(-1)

/mob/living/proc/become_blind(source)
	if(!HAS_TRAIT(src, TRAIT_BLIND))
		blind_eyes(1)
	ADD_TRAIT(src, TRAIT_BLIND, source)

/mob/living/proc/cure_nearsighted(list/sources)
	REMOVE_TRAIT(src, TRAIT_NEARSIGHT, sources)
	if(!HAS_TRAIT(src, TRAIT_NEARSIGHT))
		clear_fullscreen("nearsighted")

/mob/living/proc/become_nearsighted(source)
	if(!HAS_TRAIT(src, TRAIT_NEARSIGHT))
		overlay_fullscreen("nearsighted", /obj/screen/fullscreen/impaired, 1)
	ADD_TRAIT(src, TRAIT_NEARSIGHT, source)

/mob/living/proc/cure_husk(list/sources)
	REMOVE_TRAIT(src, TRAIT_HUSK, sources)
	if(!HAS_TRAIT(src, TRAIT_HUSK))
		REMOVE_TRAIT(src, TRAIT_DISFIGURED, "husk")
		update_body()
		return TRUE

/mob/living/proc/become_husk(source)
	if(!HAS_TRAIT(src, TRAIT_HUSK))
		ADD_TRAIT(src, TRAIT_DISFIGURED, "husk")
		update_body()
		. = TRUE
	ADD_TRAIT(src, TRAIT_HUSK, source)

/mob/living/proc/cure_fakedeath(list/sources)
	REMOVE_TRAIT(src, TRAIT_FAKEDEATH, sources)
	REMOVE_TRAIT(src, TRAIT_DEATHCOMA, sources)
	if(stat != DEAD)
		tod = null
	update_stat()

/mob/living/proc/fakedeath(source, silent = FALSE)
	if(stat == DEAD)
		return
	if(!silent)
		emote("deathgasp")
	ADD_TRAIT(src, TRAIT_FAKEDEATH, source)
	ADD_TRAIT(src, TRAIT_DEATHCOMA, source)
	tod = STATION_TIME_TIMESTAMP("hh:mm:ss")
	update_stat()

/mob/living/proc/unignore_slowdown(list/sources)
	REMOVE_TRAIT(src, TRAIT_IGNORESLOWDOWN, sources)
	update_movespeed(FALSE)

/mob/living/proc/ignore_slowdown(source)
	ADD_TRAIT(src, TRAIT_IGNORESLOWDOWN, source)
	update_movespeed(FALSE)
