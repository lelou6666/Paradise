/mob/living
	var/canEnterVentWith = "/obj/item/weapon/implant=0&/obj/item/clothing/mask/facehugger=0&/obj/item/device/radio/borg=0&/obj/machinery/camera=0"
	var/datum/middleClickOverride/middleClickOverride = null

/mob/living/carbon/Login()
	..()
	update_hud()
	return

/mob/living/carbon/prepare_huds()
	..()
	prepare_data_huds()

/mob/living/carbon/proc/prepare_data_huds()
	..()
	med_hud_set_health()
	med_hud_set_status()

/mob/living/carbon/updatehealth()
	..()
	med_hud_set_health()
	med_hud_set_status()

/mob/living/carbon/Destroy()
	for(var/atom/movable/guts in internal_organs)
		qdel(guts)
	for(var/atom/movable/food in stomach_contents)
		qdel(food)
	remove_from_all_data_huds()
	return ..()

/mob/living/carbon/blob_act()
	if (stat == DEAD)
		return
	else
		show_message("<span class='userdanger'>The blob attacks!</span>")
		adjustBruteLoss(10)

/mob/living/carbon/Move(NewLoc, direct)
	. = ..()
	if(.)
		if(src.nutrition && src.stat != 2)
			src.nutrition -= HUNGER_FACTOR/10
			if(src.m_intent == "run")
				src.nutrition -= HUNGER_FACTOR/10
		if((FAT in src.mutations) && src.m_intent == "run" && src.bodytemperature <= 360)
			src.bodytemperature += 2

		// Moving around increases germ_level faster
		if(germ_level < GERM_LEVEL_MOVE_CAP && prob(8))
			germ_level++

#define STOMACH_ATTACK_DELAY 4

/mob/living/carbon/var/last_stomach_attack //defining this here because no one would look in carbon_defines for it

/mob/living/carbon/relaymove(var/mob/user, direction)
	if(user in src.stomach_contents)
		if(last_stomach_attack + STOMACH_ATTACK_DELAY > world.time)	return

		last_stomach_attack = world.time
		for(var/mob/M in hearers(4, src))
			if(M.client)
				M.show_message(text("\red You hear something rumbling inside [src]'s stomach..."), 2)

		var/obj/item/I = user.get_active_hand()
		if(I && I.force)
			var/d = rand(round(I.force / 4), I.force)

			if(istype(src, /mob/living/carbon/human))
				var/mob/living/carbon/human/H = src
				var/obj/item/organ/external/organ = H.get_organ("chest")
				if (istype(organ))
					if(organ.take_damage(d, 0))
						H.UpdateDamageIcon()

				H.updatehealth()

			else
				src.take_organ_damage(d)

			for(var/mob/M in viewers(user, null))
				if(M.client)
					M.show_message(text("\red <B>[user] attacks [src]'s stomach wall with the [I.name]!"), 2)
			playsound(user.loc, 'sound/effects/attackblob.ogg', 50, 1)

			if(prob(src.getBruteLoss() - 50))
				for(var/atom/movable/A in stomach_contents)
					A.loc = loc
					stomach_contents.Remove(A)
				src.gib()

#undef STOMACH_ATTACK_DELAY

/mob/living/carbon/gib()
	for(var/obj/item/organ/internal/I in internal_organs)
		if(isturf(loc))
			I.remove(src)
			I.forceMove(get_turf(src))
			spawn()
				I.throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),5)

	for(var/mob/M in src)
		if(M in src.stomach_contents)
			src.stomach_contents.Remove(M)
		M.forceMove(get_turf(src))
		visible_message("<span class='danger'>[M] bursts out of [src]!</span>")
	. = ..()


/mob/living/carbon/attack_hand(mob/M as mob)
	if(!istype(M, /mob/living/carbon)) return
	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		var/obj/item/organ/external/temp = H.organs_by_name["r_hand"]
		if (H.hand)
			temp = H.organs_by_name["l_hand"]
		if(temp && !temp.is_usable())
			H << "\red You can't use your [temp.name]"
			return
	return

/mob/living/carbon/electrocute_act(shock_damage, obj/source, siemens_coeff = 1, override = 0, tesla_shock = 0)
	if(status_flags & GODMODE)	//godmode
		return 0
	if(NO_SHOCK in mutations) //shockproof
		return 0

	shock_damage *= siemens_coeff
	if(shock_damage<1 && !override)
		return 0
	if(reagents.has_reagent("teslium"))
		shock_damage *= 1.5 //If the mob has teslium in their body, shocks are 50% more damaging!
	take_overall_damage(0,shock_damage)
	//src.burn_skin(shock_damage)
	//src.adjustFireLoss(shock_damage) //burn_skin will do this for us
	//src.updatehealth()
	visible_message(
		"<span class='danger'>[src] was shocked by \the [source]!</span>", \
		"<span class='userdanger'>You feel a powerful shock coursing through your body!</span>", \
		"<span class='italics'>You hear a heavy electrical crack.</span>" \
	)
	jitteriness += 1000 //High numbers for violent convulsions
	do_jitter_animation(jitteriness)
	stuttering += 2
	if(!tesla_shock || (tesla_shock && siemens_coeff > 0.5))
		Stun(2)
	spawn(20)
		jitteriness = max(jitteriness - 990, 10) //Still jittery, but vastly less
		if(!tesla_shock || (tesla_shock && siemens_coeff > 0.5))
			Stun(3)
			Weaken(3)
	if (shock_damage > 200)
		src.visible_message(
			"<span class='danger'>[src] was arc flashed by the [source]!</span>", \
			"<span class='userdanger'>The [source] arc flashes and electrocutes you!</span>", \
			"<span class='italics'>You hear a lightning-like crack!</span>" \
		)
		playsound(loc, "sound/effects/eleczap.ogg", 50, 1, -1)
		explosion(src.loc,-1,0,2,2)
	if(override)
		return override
	else
		return shock_damage



/mob/living/carbon/proc/swap_hand()
	var/obj/item/item_in_hand = src.get_active_hand()
	if(item_in_hand) //this segment checks if the item in your hand is twohanded.
		if(istype(item_in_hand,/obj/item/weapon/twohanded))
			if(item_in_hand:wielded == 1)
				usr << "<span class='warning'>Your other hand is too busy holding the [item_in_hand.name]</span>"
				return
	src.hand = !( src.hand )
	if(hud_used.l_hand_hud_object && hud_used.r_hand_hud_object)
		if(hand)	//This being 1 means the left hand is in use
			hud_used.l_hand_hud_object.icon_state = "hand_active"
			hud_used.r_hand_hud_object.icon_state = "hand_inactive"
		else
			hud_used.l_hand_hud_object.icon_state = "hand_inactive"
			hud_used.r_hand_hud_object.icon_state = "hand_active"
	/*if (!( src.hand ))
		src.hands.dir = NORTH
	else
		src.hands.dir = SOUTH*/
	return

/mob/living/carbon/proc/activate_hand(var/selhand) //0 or "r" or "right" for right hand; 1 or "l" or "left" for left hand.

	if(istext(selhand))
		selhand = lowertext(selhand)

		if(selhand == "right" || selhand == "r")
			selhand = 0
		if(selhand == "left" || selhand == "l")
			selhand = 1

	if(selhand != src.hand)
		swap_hand()

/mob/living/carbon/proc/help_shake_act(mob/living/carbon/M)
	if (src.health >= config.health_threshold_crit)
		if(src == M && istype(src, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = src
			src.visible_message( \
				text("\blue [src] examines [].",src.gender==MALE?"himself":"herself"), \
				"\blue You check yourself for injuries." \
				)

			for(var/obj/item/organ/external/org in H.organs)
				var/status = ""
				var/brutedamage = org.brute_dam
				var/burndamage = org.burn_dam

				if(brutedamage > 0)
					status = "bruised"
				if(brutedamage > 20)
					status = "bleeding"
				if(brutedamage > 40)
					status = "mangled"
				if(brutedamage > 0 && burndamage > 0)
					status += " and "
				if(burndamage > 40)
					status += "peeling away"

				else if(burndamage > 10)
					status += "blistered"
				else if(burndamage > 0)
					status += "numb"
				if(org.status & ORGAN_DESTROYED)
					status = "MISSING!"
				if(org.status & ORGAN_MUTATED)
					status = "weirdly shapen."
				if(status == "")
					status = "OK"
				src.show_message(text("\t []My [] is [].",status=="OK"?"\blue ":"\red ",org.name,status),1)
			if(staminaloss)
				if(staminaloss > 30)
					src << "<span class='info'>You're completely exhausted.</span>"
				else
					src << "<span class='info'>You feel fatigued.</span>"
			if((SKELETON in H.mutations) && (!H.w_uniform) && (!H.wear_suit))
				H.play_xylophone()
		else
			if(player_logged)
				M.visible_message("<span class='notice'>[M] shakes [src], but they do not respond. Probably suffering from SSD.", \
				"<span class='notice'>You shake [src], but they are unresponsive. Probably suffering from SSD.</span>")
			if(lying) // /vg/: For hugs. This is how update_icon figgers it out, anyway.  - N3X15
				var/t_him = "it"
				if (src.gender == MALE)
					t_him = "him"
				else if (src.gender == FEMALE)
					t_him = "her"
				if (istype(src,/mob/living/carbon/human) && src:w_uniform)
					var/mob/living/carbon/human/H = src
					H.w_uniform.add_fingerprint(M)
				src.sleeping = max(0,src.sleeping-5)
				if(src.sleeping == 0)
					src.resting = 0
				AdjustParalysis(-3)
				AdjustStunned(-3)
				AdjustWeakened(-3)
				playsound(src.loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
				if(!player_logged)
					M.visible_message( \
						"<span class='notice'>[M] shakes [src] trying to wake [t_him] up!</span>",\
						"<span class='notice'>You shake [src] trying to wake [t_him] up!</span>",\
						)
			// BEGIN HUGCODE - N3X
			else
				playsound(get_turf(src), 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
				if(M.zone_sel.selecting == "head")
					M.visible_message(\
					"<span class='notice'>[M] pats [src] on the head.</span>",\
					"<span class='notice'>You pat [src] on the head.</span>",\
					)
				else

					M.visible_message(\
					"<span class='notice'>[M] gives [src] a [pick("hug","warm embrace")].</span>",\
					"<span class='notice'>You hug [src].</span>",\
					)
					if(istype(src,/mob/living/carbon/human))
						var/mob/living/carbon/human/H = src
						if(H.w_uniform)
							H.w_uniform.add_fingerprint(M)


/mob/living/carbon/proc/eyecheck()
	return 0

/mob/living/carbon/proc/tintcheck()
	return 0

/mob/living/carbon/proc/getDNA()
	return dna

/mob/living/carbon/proc/setDNA(var/datum/dna/newDNA)
	dna = newDNA


var/list/ventcrawl_machinery = list(/obj/machinery/atmospherics/unary/vent_pump, /obj/machinery/atmospherics/unary/vent_scrubber)

/mob/living/handle_ventcrawl(var/atom/clicked_on) // -- TLE -- Merged by Carn
	if(!Adjacent(clicked_on))
		return

	var/ventcrawlerlocal = 0
	if(ventcrawler)
		ventcrawlerlocal = ventcrawler

	if(!ventcrawler)
		if(ishuman(src))
			var/mob/living/carbon/human/H = src
			ventcrawlerlocal = H.species.ventcrawler

	if(!ventcrawlerlocal)	return

	if(stat)
		src << "You must be conscious to do this!"
		return

	if(lying)
		src << "You can't vent crawl while you're stunned!"
		return

	if(buckled_mob)
		src << "You can't vent crawl with [buckled_mob] on you!"
		return

	var/obj/machinery/atmospherics/unary/vent_found

	if(clicked_on)
		vent_found = clicked_on
		if(!istype(vent_found) || !vent_found.can_crawl_through())
			vent_found = null


	if(!vent_found)
		for(var/obj/machinery/atmospherics/machine in range(1,src))
			if(is_type_in_list(machine, ventcrawl_machinery))
				vent_found = machine

			if(!vent_found.can_crawl_through())
				vent_found = null

			if(vent_found)
				break

	if(vent_found)
		if(vent_found.parent && (vent_found.parent.members.len || vent_found.parent.other_atmosmch))
			visible_message("<span class='notice'>[src] begins climbing into the ventilation system...</span>", \
							"<span class='notice'>You begin climbing into the ventilation system...</span>")

			if(!do_after(src, 45, target = src))
				return

			if(!client)
				return

			if(iscarbon(src) && contents.len && ventcrawlerlocal < 2)//It must have atleast been 1 to get this far
				for(var/obj/item/I in contents)
					var/failed = 0
					if(istype(I, /obj/item/weapon/implant))
						continue
					if(istype(I, /obj/item/organ))
						continue
					else
						failed++

					if(failed)
						src << "<span class='warning'>You can't crawl around in the ventilation ducts with items!</span>"
						return

			visible_message("<b>[src] scrambles into the ventilation ducts!</b>", "You climb into the ventilation system.")
			src.loc = vent_found
			add_ventcrawl(vent_found)

	else
		src << "<span class='warning'>This ventilation duct is not connected to anything!</span>"


/mob/living/proc/add_ventcrawl(obj/machinery/atmospherics/starting_machine)
	if(!istype(starting_machine) || !starting_machine.returnPipenet())
		return
	var/datum/pipeline/pipeline = starting_machine.returnPipenet()
	var/list/totalMembers = list()
	totalMembers |= pipeline.members
	totalMembers |= pipeline.other_atmosmch
	for(var/obj/machinery/atmospherics/A in totalMembers)
		if(!A.pipe_image)
			A.pipe_image = image(A, A.loc, layer = 20, dir = A.dir) //the 20 puts it above Byond's darkness (not its opacity view)
		pipes_shown += A.pipe_image
		client.images += A.pipe_image

/mob/living/proc/remove_ventcrawl()
	if(client)
		for(var/image/current_image in pipes_shown)
			client.images -= current_image
		client.eye = src

	pipes_shown.len = 0

//OOP
/atom/proc/update_pipe_vision()
	return

/mob/living/update_pipe_vision()
	if(pipes_shown.len)
		if(!istype(loc, /obj/machinery/atmospherics))
			remove_ventcrawl()
	else
		if(istype(loc, /obj/machinery/atmospherics))
			add_ventcrawl(loc)

/mob/living/carbon/clean_blood()
	. = ..()
	if(ishuman(src))
		var/mob/living/carbon/human/H = src
		if(H.gloves)
			if(H.gloves.clean_blood())
				H.update_inv_gloves(0,0)
			H.gloves.germ_level = 0
		else
			if(H.bloody_hands)
				H.bloody_hands = 0
				H.update_inv_gloves(0,0)
			H.germ_level = 0
	update_icons()	//apply the now updated overlays to the mob


//Throwing stuff

/mob/living/carbon/proc/toggle_throw_mode()
	if (in_throw_mode)
		throw_mode_off()
	else
		throw_mode_on()

/mob/living/carbon/proc/throw_mode_off()
	src.in_throw_mode = 0
	if(src.throw_icon) //in case we don't have the HUD and we use the hotkey
		src.throw_icon.icon_state = "act_throw_off"

/mob/living/carbon/proc/throw_mode_on()
	src.in_throw_mode = 1
	if(src.throw_icon)
		src.throw_icon.icon_state = "act_throw_on"

/mob/proc/throw_item(atom/target)
	return

/mob/living/carbon/throw_item(atom/target)
	throw_mode_off()
	if(usr.stat || !target)
		return
	if(target.type == /obj/screen)
		return

	var/atom/movable/item = src.get_active_hand()

	if(!item || (item.flags & NODROP))
		return

	if (istype(item, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = item
		item = G.get_mob_if_throwable() //throw the person instead of the grab
		if(ismob(item))
			var/turf/start_T = get_turf(loc) //Get the start and target tile for the descriptors
			var/turf/end_T = get_turf(target)
			if(start_T && end_T)
				var/mob/M = item
				var/start_T_descriptor = "<font color='#6b5d00'>tile at [start_T.x], [start_T.y], [start_T.z] in area [get_area(start_T)]</font>"
				var/end_T_descriptor = "<font color='#6b4400'>tile at [end_T.x], [end_T.y], [end_T.z] in area [get_area(end_T)]</font>"

				M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been thrown by [key_name(usr)] from [start_T_descriptor] with the target [end_T_descriptor]</font>")
				usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Has thrown [key_name(M)] from [start_T_descriptor] with the target [end_T_descriptor]</font>")
				msg_admin_attack("[key_name_admin(usr)] has thrown [key_name_admin(M)] from [start_T_descriptor] with the target [end_T_descriptor]")

				if(!iscarbon(usr))
					M.LAssailant = null
				else
					M.LAssailant = usr

	if(!item)
		return //Grab processing has a chance of returning null
	if(!ismob(item)) //Honk mobs don't have a dropped() proc honk
		unEquip(item)
	update_icons()

	if (istype(usr, /mob/living/carbon)) //Check if a carbon mob is throwing. Modify/remove this line as required.
		item.loc = usr.loc
		if(src.client)
			src.client.screen -= item
		if(istype(item, /obj/item))
			item:dropped(src) // let it know it's been dropped

	//actually throw it!
	if (item)
		item.layer = initial(item.layer)
		src.visible_message("\red [src] has thrown [item].")

		newtonian_move(get_dir(target, src))

		item.throw_at(target, item.throw_range, item.throw_speed, src)
/*
/mob/living/carbon/fire_act(datum/gas_mixture/air, exposed_temperature, exposed_volume)
	..()
	src.IgniteMob()
	bodytemperature = max(bodytemperature, BODYTEMP_HEAT_DAMAGE_LIMIT+10)
*/
/mob/living/carbon/can_use_hands()
	if(handcuffed)
		return 0
	if(buckled && ! istype(buckled, /obj/structure/stool/bed/chair)) // buckling does not restrict hands
		return 0
	return 1

/mob/living/carbon/restrained()
	if (handcuffed)
		return 1
	return

/mob/living/carbon/unEquip(obj/item/I) //THIS PROC DID NOT CALL ..()
	. = ..() //Sets the default return value to what the parent returns.
	if(!. || !I) //We don't want to set anything to null if the parent returned 0.
		return

	if(I == back)
		back = null
		update_inv_back()
	else if(I == wear_mask)
		if(istype(src, /mob/living/carbon/human)) //If we don't do this hair won't be properly rebuilt.
			return
		wear_mask = null
		update_inv_wear_mask()
	else if(I == handcuffed)
		handcuffed = null
		if(buckled && buckled.buckle_requires_restraints)
			buckled.unbuckle_mob()
		update_inv_handcuffed()
	else if(I == legcuffed)
		legcuffed = null
		update_inv_legcuffed()

/mob/living/carbon/show_inv(mob/user)
	user.set_machine(src)
	
	var/dat = {"<table>
	<tr><td><B>Left Hand:</B></td><td><A href='?src=\ref[src];item=[slot_l_hand]'>[(l_hand && !(l_hand.flags&ABSTRACT)) ? l_hand : "<font color=grey>Empty</font>"]</A></td></tr>
	<tr><td><B>Right Hand:</B></td><td><A href='?src=\ref[src];item=[slot_r_hand]'>[(r_hand && !(r_hand.flags&ABSTRACT)) ? r_hand : "<font color=grey>Empty</font>"]</A></td></tr>
	<tr><td>&nbsp;</td></tr>"}
	
	dat += "<tr><td><B>Back:</B></td><td><A href='?src=\ref[src];item=[slot_back]'>[(back && !(back.flags&ABSTRACT)) ? back : "<font color=grey>Empty</font>"]</A>"
	if(istype(wear_mask, /obj/item/clothing/mask) && istype(back, /obj/item/weapon/tank))
		dat += "&nbsp;<A href='?src=\ref[src];internal=[slot_back]'>[internal ? "Disable Internals" : "Set Internals"]</A>"

	dat += "</td></tr><tr><td>&nbsp;</td></tr>"

	dat += "<tr><td><B>Head:</B></td><td><A href='?src=\ref[src];item=[slot_head]'>[(head && !(head.flags&ABSTRACT)) ? head : "<font color=grey>Empty</font>"]</A></td></tr>"

	dat += "<tr><td><B>Mask:</B></td><td><A href='?src=\ref[src];item=[slot_wear_mask]'>[(wear_mask && !(wear_mask.flags&ABSTRACT)) ? wear_mask : "<font color=grey>Empty</font>"]</A></td></tr>"

	if(handcuffed)
		dat += "<tr><td><B>Handcuffed:</B> <A href='?src=\ref[src];item=[slot_handcuffed]'>Remove</A></td></tr>"
	if(legcuffed)
		dat += "<tr><td><A href='?src=\ref[src];item=[slot_legcuffed]'>Legcuffed</A></td></tr>"

	dat += {"</table>
	<A href='?src=\ref[user];mach_close=mob\ref[src]'>Close</A>
	"}

	var/datum/browser/popup = new(user, "mob\ref[src]", "[src]", 440, 500)
	popup.set_content(dat)
	popup.open()

/mob/living/carbon/Topic(href, href_list)
	..()
	//strip panel
	if(!usr.stat && usr.canmove && !usr.restrained() && in_range(src, usr))
		if(href_list["internal"])
			var/slot = text2num(href_list["internal"])
			var/obj/item/ITEM = get_item_by_slot(slot)
			if(ITEM && istype(ITEM, /obj/item/weapon/tank))
				visible_message("<span class='danger'>[usr] tries to [internal ? "close" : "open"] the valve on [src]'s [ITEM].</span>", \
								"<span class='userdanger'>[usr] tries to [internal ? "close" : "open"] the valve on [src]'s [ITEM].</span>")

				var/no_mask
				if(!(wear_mask && wear_mask.flags & AIRTIGHT))
					if(!(head && head.flags & AIRTIGHT))
						no_mask = 1
				if(no_mask)
					usr << "<span class='warning'>[src] is not wearing a suitable mask or helmet!</span>"
					return

				if(do_mob(usr, src, POCKET_STRIP_DELAY))
					if(internal)
						internal = null
						if(internals)
							internals.icon_state = "internal0"
					else
						var/no_mask2
						if(!(wear_mask && wear_mask.flags & AIRTIGHT))
							if(!(head && head.flags & AIRTIGHT))
								no_mask2 = 1
						if(no_mask2)
							usr << "<span class='warning'>[src] is not wearing a suitable mask or helmet!</span>"
							return
						internal = ITEM
						if(internals)
							internals.icon_state = "internal1"

					visible_message("<span class='danger'>[usr] [internal ? "opens" : "closes"] the valve on [src]'s [ITEM].</span>", \
									"<span class='userdanger'>[usr] [internal ? "opens" : "closes"] the valve on [src]'s [ITEM].</span>")

/mob/living/carbon/get_item_by_slot(slot_id)
	switch(slot_id)
		if(slot_back)
			return back
		if(slot_wear_mask)
			return wear_mask
		if(slot_handcuffed)
			return handcuffed
		if(slot_legcuffed)
			return legcuffed
		if(slot_l_hand)
			return l_hand
		if(slot_r_hand)
			return r_hand
	return null


//generates realistic-ish pulse output based on preset levels
/mob/living/carbon/proc/get_pulse(var/method)	//method 0 is for hands, 1 is for machines, more accurate
	var/temp = 0								//see setup.dm:694
	switch(src.pulse)
		if(PULSE_NONE)
			return "0"
		if(PULSE_SLOW)
			temp = rand(40, 60)
			return num2text(method ? temp : temp + rand(-10, 10))
		if(PULSE_NORM)
			temp = rand(60, 90)
			return num2text(method ? temp : temp + rand(-10, 10))
		if(PULSE_FAST)
			temp = rand(90, 120)
			return num2text(method ? temp : temp + rand(-10, 10))
		if(PULSE_2FAST)
			temp = rand(120, 160)
			return num2text(method ? temp : temp + rand(-10, 10))
		if(PULSE_THREADY)
			return method ? ">250" : "extremely weak and fast, patient's artery feels like a thread"
//			output for machines^	^^^^^^^output for people^^^^^^^^^



/mob/living/carbon/proc/canBeHandcuffed()
	return 0

/mob/living/carbon/fall(forced)
    loc.handle_fall(src, forced)//it's loc so it doesn't call the mob's handle_fall which does nothing

/mob/living/carbon/is_muzzled()
	return(istype(src.wear_mask, /obj/item/clothing/mask/muzzle))

/mob/living/carbon/get_standard_pixel_y_offset(lying = 0)
	if(lying)
		if(buckled)	return initial(pixel_y)
		return -6
	else
		return initial(pixel_y)

/mob/living/carbon/emp_act(severity)
	for(var/obj/item/organ/internal/O in internal_organs)
		O.emp_act(severity)
	..()

/mob/living/carbon/Stat()
	if(statpanel("Status"))
		var/obj/item/organ/internal/xenos/plasmavessel/vessel = get_int_organ(/obj/item/organ/internal/xenos/plasmavessel)
		if(vessel)
			stat(null, "Plasma Stored: [vessel.stored_plasma]/[vessel.max_plasma]")
	..()

/mob/living/carbon/get_all_slots()
	return list(l_hand,
				r_hand,
				handcuffed,
				legcuffed,
				back,
				wear_mask)

/mob/living/carbon/proc/uncuff()
	if (handcuffed)
		var/obj/item/weapon/W = handcuffed
		handcuffed = null
		if (buckled && buckled.buckle_requires_restraints)
			buckled.unbuckle_mob()
		update_inv_handcuffed()
		if (client)
			client.screen -= W
		if (W)
			W.loc = loc
			W.dropped(src)
			if (W)
				W.layer = initial(W.layer)
	if (legcuffed)
		var/obj/item/weapon/W = legcuffed
		legcuffed = null
		update_inv_legcuffed()
		if (client)
			client.screen -= W
		if (W)
			W.loc = loc
			W.dropped(src)
			if (W)
				W.layer = initial(W.layer)


/mob/living/carbon/proc/slip(var/description, var/stun, var/weaken, var/tilesSlipped, var/walkSafely, var/slipAny)
	if (flying || buckled || (walkSafely && m_intent == "walk"))
		return
	if ((lying) && (!(tilesSlipped)))
		return
	if (!(slipAny))
		if (istype(src, /mob/living/carbon/human))
			var/mob/living/carbon/human/H = src
			if ((isobj(H.shoes) && H.shoes.flags & NOSLIP) || H.species.bodyflags & FEET_NOSLIP)
				return
	if (tilesSlipped)
		for(var/t = 0, t<=tilesSlipped, t++)
			spawn (t) step(src, src.dir)
	stop_pulling()
	src << "<span class='notice'>You slipped on the [description]!</span>"
	playsound(src.loc, 'sound/misc/slip.ogg', 50, 1, -3)
	if (stun)
		Stun(stun)
	Weaken(weaken)
	return 1

/mob/living/carbon/proc/can_eat(flags = 255)
	return 1

/mob/living/carbon/proc/eat(var/obj/item/weapon/reagent_containers/food/toEat, mob/user)
	if(!istype(toEat))
		return 0
	var/fullness = 0
	if(istype(toEat, /obj/item/weapon/reagent_containers/food/snacks))
		fullness = nutrition + (reagents.get_reagent_amount("nutriment") * 20) + (reagents.get_reagent_amount("protein") * 25) + (reagents.get_reagent_amount("plantmatter") * 25)
	if(user == src)
		if(istype(toEat, /obj/item/weapon/reagent_containers/food/drinks))
			if(!selfDrink(toEat))
				return 0
		else
			if(!selfFeed(toEat, fullness))
				return 0
	else
		if(!forceFed(toEat, user, fullness))
			return 0
	consume(toEat)
	return 1

/mob/living/carbon/proc/selfFeed(var/obj/item/weapon/reagent_containers/food/toEat, fullness)
	if(istype(toEat, /obj/item/weapon/reagent_containers/food/pill))
		src << "<span class='notify'>You [toEat.apply_method] [toEat].</span>"
	else
		if (fullness <= 50)
			src << "<span class='warning'>You hungrily chew out a piece of [toEat] and gobble it!</span>"
		else if (fullness > 50 && fullness <= 150)
			src << "<span class='notice'>You hungrily begin to eat [toEat].</span>"
		else if (fullness > 150 && fullness <= 350)
			src << "<span class='notice'>You take a bite of [toEat].</span>"
		else if (fullness > 350 && fullness <= 550)
			src << "<span class='notice'>You unwillingly chew a bit of [toEat].</span>"
		else if (fullness > (550 * (1 + overeatduration / 2000)))	// The more you eat - the more you can eat
			src << "<span class='warning'>You cannot force any more of [toEat] to go down your throat.</span>"
			return 0
	return 1

/mob/living/carbon/proc/selfDrink(var/obj/item/weapon/reagent_containers/food/drinks/toDrink, mob/user)
	return 1

/mob/living/carbon/proc/forceFed(var/obj/item/weapon/reagent_containers/food/toEat, mob/user, fullness)
	if (fullness <= (550 * (1 + overeatduration / 1000)))
		visible_message("<span class='warning'>[user] attempts to force [src] to [toEat.apply_method] [toEat].</span>")
	else
		visible_message("<span class='warning'>[user] cannot force anymore of [toEat] down [src]'s throat.</span>")
		return 0
	if(!do_mob(user, src))
		return 0
	forceFedAttackLog(toEat, user)
	visible_message("<span class='warning'>[user] forces [src] to [toEat.apply_method] [toEat].</span>")
	return 1

/mob/living/carbon/proc/forceFedAttackLog(var/obj/item/weapon/reagent_containers/food/toEat, mob/user)
	attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been fed [toEat.name] by [user.name] ([user.ckey]) Reagents: [toEat.reagentlist(toEat)]</font>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>Fed [toEat.name] to [name] ([ckey]) Reagents: [toEat.reagentlist(toEat)]</font>")
	log_attack("[user.name] ([user.ckey]) fed [name] ([ckey]) with [toEat.name] Reagents: [toEat.reagentlist(toEat)] (INTENT: [uppertext(user.a_intent)])")
	if(!iscarbon(user))
		LAssailant = null
	else
		LAssailant = user


/*TO DO - If/when stomach organs are introduced, override this at the human level sending the item to the stomach
so that different stomachs can handle things in different ways VB*/
/mob/living/carbon/proc/consume(var/obj/item/weapon/reagent_containers/food/toEat)
	if(!toEat.reagents)
		return
	if(toEat.consume_sound)
		playsound(loc, toEat.consume_sound, rand(10,50), 1)
	if(toEat.reagents.total_volume)
		toEat.reagents.reaction(src, toEat.apply_type)
		spawn(0)
			if(toEat.reagents.total_volume > toEat.bitesize)
				toEat.reagents.trans_to(src, toEat.bitesize*toEat.transfer_efficiency)
			else
				toEat.reagents.trans_to(src, toEat.reagents.total_volume*toEat.transfer_efficiency)

/mob/living/carbon/get_access()
	. = ..()

	var/obj/item/I = get_active_hand()
	if(I)
		. |= I.GetAccess()
