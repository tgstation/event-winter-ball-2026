/// Datum holding one or multiple participants for a fight
/// When datums in the queue hold 6 participants that could be split 3/3, they're compressed into 2 teams
/// and excess datums are deleted. People can join existing teams by prompting the owner, up to 3 per team.
/datum/duel_group
	/// Participants in the group
	var/list/datum/duel_member/members = list()
	/// Mob who created the group
	var/mob/living/carbon/human/owner = null
	/// If we're participating in an active duel at the moment
	var/datum/arena_duel/active_duel = null
	/// Console that created us
	var/obj/machinery/computer/ragecage_signup/console = null
	/// Should we join other groups when there's enough people to start a fight?
	var/join_random = FALSE
	/// Arena type picked by the owner
	var/arena_type = "_random"

/datum/duel_group/New(mob/living/carbon/human/creator, obj/machinery/computer/ragecage_signup/new_console, join_random = FALSE, arena_type = "_random")
	. = ..()
	console = new_console
	owner = creator
	members += new /datum/duel_member(creator, src)
	src.join_random = join_random
	src.arena_type = arena_type

/datum/duel_group/Destroy(force)
	. = ..()
	owner = null
	active_duel = null
	if (src in console?.duels)
		console.duels -= src
	else
		console.trios -= src
	console = null
	QDEL_LIST(members)

/// Stores info about the mob and their belongings
/datum/duel_member
	var/mob/living/carbon/human/owner = null
	/// Assoc list of items -> slot/storage item
	var/list/obj/item/belongings = list()
	/// Duel group we belong to
	var/datum/duel_group/group = null

/datum/duel_member/New(mob/living/carbon/human/new_owner, datum/duel_group/new_group)
	. = ..()
	owner = new_owner
	group = new_group
	RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(owner_deleted))

/datum/duel_member/Destroy(force)
	owner = null
	group = null
	belongings.Cut()
	return ..()

/datum/duel_member/proc/owner_deleted()
	SIGNAL_HANDLER
	group?.active_duel?.duelant_death(src)
	qdel(src)

/// Track all of mob's equipment so we can give it back to them when they get TPed out
/datum/duel_member/proc/store_equipment()
	for (var/obj/item/thing as anything in owner.get_all_gear())
		if (thing.loc == owner)
			belongings[thing] = owner.get_slot_by_item(thing)
		else
			belongings[thing] = thing.loc
		RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(on_delete), TRUE)

/datum/duel_member/proc/on_delete(obj/item/deleted)
	SIGNAL_HANDLER
	belongings -= deleted

/// Return all of mob's equipment and delete whatever doesn't fit into them
/datum/duel_member/proc/return_equipment()
	var/turf/owner_turf = get_turf(owner)
	for (var/obj/item/thing as anything in belongings)
		if (get(thing, /mob) == owner)
			continue

		if (ismob(thing.loc))
			owner.temporarilyRemoveItemFromInventory(thing)

		if (!isatom(belongings[thing]))
			if (!owner.equip_to_slot_if_possible(thing, belongings[thing]))
				thing.forceMove(owner_turf)
			continue

		var/atom/storage = belongings[thing]
		if (thing.loc == storage)
			continue

		if (!storage.atom_storage?.attempt_insert(thing, null, TRUE, STORAGE_FULLY_LOCKED, FALSE))
			thing.forceMove(owner_turf)

	belongings.Cut()

/datum/duel_member/proc/start_duel(datum/arena_duel/active_duel, obj/effect/landmark/ragecage/spawn_point)
	to_chat(owner, span_userdanger("Lights, camera, stage! The arena is yours!"))
	store_equipment()
	owner.revive(ADMIN_HEAL_ALL, force_grab_ghost = TRUE)
	RegisterSignal(owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_changed))
	new /obj/effect/temp_visual/dir_setting/ninja/cloak(get_turf(owner))
	do_sparks(2, FALSE, owner)
	owner.alpha = 0
	owner.forceMove(get_turf(spawn_point))
	owner.Immobilize(1 SECONDS, ignore_canstun = TRUE)
	new /obj/effect/temp_visual/dir_setting/ninja(get_turf(owner))
	do_sparks(2, FALSE, owner)
	addtimer(CALLBACK(src, PROC_REF(finish_start)), 9)

/datum/duel_member/proc/finish_start()
	owner.alpha = 255
	owner.SetImmobilized(0)

/datum/duel_member/proc/end_duel(obj/effect/landmark/ragecage_exit/exit)
	if (!exit)
		stack_trace("Duel ended with no or not enough exit landmarks!")
		exit = locate() in GLOB.landmarks_list // don't softlock people

	do_sparks(2, FALSE, owner)
	owner.revive(ADMIN_HEAL_ALL, force_grab_ghost = TRUE)
	new /obj/effect/temp_visual/dir_setting/ninja/cloak(get_turf(owner))
	owner.forceMove(get_turf(exit))
	do_sparks(2, FALSE, owner)
	new /obj/effect/temp_visual/dir_setting/ninja(get_turf(owner))
	return_equipment()
	UnregisterSignal(owner, COMSIG_MOB_STATCHANGE)

/datum/duel_member/proc/on_stat_changed(mob/living/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if (old_stat != DEAD && new_stat == DEAD && !QDELETED(source))
		group?.active_duel?.duelant_death(src)

/datum/arena_duel
	// Two participating groups
	var/datum/duel_group/first_group = null
	var/datum/duel_group/second_group = null
	/// Console that created us
	var/obj/machinery/computer/ragecage_signup/console = null

/datum/arena_duel/New(obj/machinery/computer/ragecage_signup/new_console, datum/duel_group/first, datum/duel_group/second)
	. = ..()
	console = new_console
	first_group = first
	second_group = second
	var/map_id = pick(first_group.arena_type, second_group.arena_type)
	if (map_id == "_random")
		map_id = pick(console.arena_types - "_random")
	console.load_arena(map_id)
	first_group.active_duel = src
	second_group.active_duel = src
	start_fight()

/datum/arena_duel/Destroy(force)
	. = ..()
	QDEL_NULL(first_group)
	QDEL_NULL(second_group)
	console.active_duel = null
	INVOKE_ASYNC(console, TYPE_PROC_REF(/obj/machinery/computer/ragecage_signup, check_matches))
	console = null

/datum/arena_duel/proc/start_fight()
	var/list/obj/effect/landmark/ragecage/first_team = list()
	var/list/obj/effect/landmark/ragecage/second_team = list()
	for (var/obj/effect/landmark/ragecage/mark in GLOB.landmarks_list)
		if (mark.index == ARENA_FIRST_FIGHTER)
			first_team += mark
		else
			second_team += mark

	for (var/datum/duel_member/member as anything in first_group.members)
		var/landmark = pick_n_take(first_team)
		if (!landmark)
			stack_trace("Arena duel was unable to find enough first team landmarks for a duel!")
			break
		member.start_duel(src, landmark)

	for (var/datum/duel_member/member as anything in second_group.members)
		var/landmark = pick_n_take(second_team)
		if (!landmark)
			stack_trace("Arena duel was unable to find enough second team landmarks for a duel!")
			break
		member.start_duel(src, landmark)

/// Called whenever a duelant dies, check if there are any other living duelants from the same team and if not, ends the fight
/// Not using a num tracker because this is barely called and tracking revives is just a pain in the ass
/datum/arena_duel/proc/duelant_death(datum/duel_member/just_died)
	var/datum/duel_group/loser_team = null
	if (just_died in first_group.members)
		loser_team = first_group
	else if (just_died in second_group.members)
		loser_team = second_group

	// Just in case
	if (!loser_team)
		return

	for (var/datum/duel_member/member as anything in loser_team.members - just_died)
		if (member.owner?.stat != DEAD)
			return

	// No living team members remain, end the fight
	end_fight(loser_team)

/datum/arena_duel/proc/end_fight(datum/duel_group/loser_group)
	var/list/obj/effect/landmark/ragecage_exit/exits = list()
	for (var/obj/effect/landmark/ragecage_exit/mark in GLOB.landmarks_list)
		exits += mark

	var/datum/duel_group/winner_group = loser_group == first_group ? second_group : first_group
	for (var/datum/duel_member/winner as anything in winner_group?.members)
		var/mob/living/carbon/human/winner_mob = winner.owner
		to_chat(winner_mob, span_green(span_big("You have won the match!")))
		winner.end_duel(pick_n_take(exits))

	for (var/datum/duel_member/loser as anything in (winner_group ? loser_group.members : first_group.members + second_group.members)) // so in case the duel ends without a winner, both sides lose
		var/mob/living/carbon/human/loser_mob = loser.owner
		to_chat(loser_mob, span_red(span_big("You have lost the match!")))
		loser.end_duel(pick_n_take(exits))

	qdel(src)
