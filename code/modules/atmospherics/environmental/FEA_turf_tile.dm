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
		var/gas_mixture/air = new
		air.copy_from_turf(src)
		SSair.add_to_sources(src,air)
	. = ..()

/turf/open/Destroy()
	SSair.remove_air(src)
	return ..()

/turf/proc/get_extools_air()

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
