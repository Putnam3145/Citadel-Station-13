/turf
	var/initial_gas_mix = OPENTURF_DEFAULT_ATMOS

/turf/return_air()
	RETURN_TYPE(/datum/gas_mixture)
	var/datum/gas_mixture/GM = new
	GM.copy_from_turf(src)
	return GM



/turf/open
	var/list/atmos_overlay_types

/turf/open/Initialize()
	if(!blocks_air)
		var/datum/gas_mixture/air = new
		air.copy_from_turf(src)
		SSair.add_to_sources(src,air)
	. = ..()

/turf/open/Destroy()
	SSair.remove_air(src)
	return ..()

/turf/proc/get_extools_air()

/turf/proc/set_processing_level()

/turf/open/return_air()
	RETURN_TYPE(/datum/gas_mixture)
	var/datum/gas_mixture/ret_air = new
	get_extools_air(ret_air)
	return ret_air

/turf/open/assume_air(datum/gas_mixture/giver) //use this and this only for adding air to turfs
	if(!giver)
		return FALSE
	SSair.add_to_sources(src,giver)
	update_visuals()
	return TRUE

/turf/open/remove_air(amount)
	var/datum/gas_mixture/ours = return_air()
	var/datum/gas_mixture/removed = ours.remove(amount)
	SSair.add_to_sources(src,ours)
	update_visuals()
	return removed

/turf/open/proc/copy_air_with_tile(turf/open/T)
	if(istype(T))
		SSair.add_to_sources(T,return_air())

/turf/open/proc/copy_air(datum/gas_mixture/copy)
	if(copy)
		SSair.add_to_sources(src,copy)

/////////////////////////GAS OVERLAYS//////////////////////////////


/turf/open/proc/update_visuals()

	var/list/atmos_overlay_types = src.atmos_overlay_types // Cache for free performance
	var/list/new_overlay_types = list()
	var/static/list/nonoverlaying_gases = typecache_of_gases_with_no_overlays()

	if(!air) // 2019-05-14: was not able to get this path to fire in testing. Consider removing/looking at callers -Naksu
		if (atmos_overlay_types)
			for(var/overlay in atmos_overlay_types)
				vis_contents -= overlay
			src.atmos_overlay_types = null
		return

	for(var/id in air.get_gases())
		if (nonoverlaying_gases[id])
			continue
		var/gas_overlay = GLOB.meta_gas_overlays[id]
		if(gas_overlay && air.get_moles(id) > GLOB.meta_gas_visibility[META_GAS_MOLES_VISIBLE])
			new_overlay_types += gas_overlay[min(FACTOR_GAS_VISIBLE_MAX, CEILING(air.get_moles(id) / MOLES_GAS_VISIBLE_STEP, 1))]

	if (atmos_overlay_types)
		for(var/overlay in atmos_overlay_types-new_overlay_types) //doesn't remove overlays that would only be added
			vis_contents -= overlay

	if (length(new_overlay_types))
		if (atmos_overlay_types)
			vis_contents += new_overlay_types - atmos_overlay_types //don't add overlays that already exist
		else
			vis_contents += new_overlay_types

	UNSETEMPTY(new_overlay_types)
	src.atmos_overlay_types = new_overlay_types

/turf/open/proc/set_visuals(list/new_overlay_types)
	if (atmos_overlay_types)
		for(var/overlay in atmos_overlay_types-new_overlay_types) //doesn't remove overlays that would only be added
			vis_contents -= overlay

	if (length(new_overlay_types))
		if (atmos_overlay_types)
			vis_contents += new_overlay_types - atmos_overlay_types //don't add overlays that already exist
		else
			vis_contents += new_overlay_types
	UNSETEMPTY(new_overlay_types)
	src.atmos_overlay_types = new_overlay_types

/proc/typecache_of_gases_with_no_overlays()
	. = list()
	for (var/gastype in subtypesof(/datum/gas))
		var/datum/gas/gasvar = gastype
		if (!initial(gasvar.gas_overlay))
			.[gastype] = TRUE

/turf/proc/get_velocity()

/turf/open/proc/move_with_air()
	var/diff = get_velocity()
	for(var/obj/M in src)
		if(!M.anchored && !M.pulledby && M.last_high_pressure_movement_air_cycle < SSair.times_fired)
			M.experience_air_movement(diff[1], diff[2], 0, pressure_specific_target)
	for(var/mob/M in src)
		if(!M.anchored && !M.pulledby && M.last_high_pressure_movement_air_cycle < SSair.times_fired)
			M.experience_air_movement(diff[1], diff[2], 0, pressure_specific_target)
	/*
	if(pressure_difference > 100)
		new /obj/effect/temp_visual/dir_setting/space_wind(src, pressure_direction, clamp(round(sqrt(pressure_difference) * 2), 10, 255))
	*/

/atom/movable/var/pressure_resistance = 10
/atom/movable/var/last_high_pressure_movement_air_cycle = 0

/atom/movable/proc/experience_air_movement(pressure_difference, direction, pressure_resistance_prob_delta = 0, throw_target)
	var/const/PROBABILITY_OFFSET = 25
	var/const/PROBABILITY_BASE_PRECENT = 75
	var/max_force = sqrt(pressure_difference)*(MOVE_FORCE_DEFAULT / 5)
	set waitfor = 0
	var/move_prob = 100
	if (pressure_resistance > 0)
		move_prob = (pressure_difference/pressure_resistance*PROBABILITY_BASE_PRECENT)-PROBABILITY_OFFSET
	move_prob += pressure_resistance_prob_delta
	if (move_prob > PROBABILITY_OFFSET && prob(move_prob) && (move_resist != INFINITY) && (!anchored && (max_force >= (move_resist * MOVE_FORCE_PUSH_RATIO))) || (anchored && (max_force >= (move_resist * MOVE_FORCE_FORCEPUSH_RATIO))))
		step(src, direction)
