// Prevents mapload objects from being destroyed
/obj/structure/Initialize(mapload)
	. = ..()
	if(!mapload)
		return
	resistance_flags |= INDESTRUCTIBLE
	obj_flags |= NO_DEBRIS_AFTER_DECONSTRUCTION

/obj/machinery/Initialize(mapload)
	. = ..()
	if(!mapload)
		return
	resistance_flags |= INDESTRUCTIBLE
	obj_flags |= NO_DEBRIS_AFTER_DECONSTRUCTION

/turf
	explosive_resistance = 50

/turf/rust_heretic_act()
	return

/turf/acid_act(acidpwr, acid_volume, acid_id)
	return FALSE

/turf/Melt()
	to_be_destroyed = FALSE
	return src

/turf/singularity_act()
	return
