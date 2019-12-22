/*
	Global associative list for caching humanoid icons.
	Index format m or f, followed by a string of 0 and 1 to represent bodyparts followed by husk fat hulk skeleton 1 or 0.
	TODO: Proper documentation
	icon_key is [species.race_key][g][husk][fat][hulk][skeleton][ethnicity]
*/
var/global/list/human_icon_cache = list()
var/global/list/tail_icon_cache = list()

/proc/overlay_image(icon,icon_state,color,flags)
	var/image/ret = image(icon,icon_state)
	ret.color = color
	ret.appearance_flags = flags
	return ret

/*
	Global associative list for caching uniform masks.
	Each index is just 0 or 1 for not removed and removed (as in previously delimbed).
*/
var/global/list/uniform_mask_cache = list()

	///////////////////////
	//UPDATE_ICONS SYSTEM//
	///////////////////////
/*

Another feature of this new system is that our lists are indexed. This means we can update specific overlays!
So we only regenerate icons when we need them to be updated! This is the main saving for this system.

In practice this means that:
	Everytime you do something minor like take a pen out of your pocket, we only update the in-hand overlay
	etc...


There are several things that need to be remembered:

>	Whenever we do something that should cause an overlay to update (which doesn't use standard procs
	( i.e. you do something like l_hand = /obj/item/something new(src) )
	You will need to call the relevant update_inv_* proc:
		update_inv_head()
		update_inv_wear_suit()
		update_inv_gloves()
		update_inv_shoes()
		update_inv_w_uniform()
		update_inv_glasse()
		update_inv_l_hand()
		update_inv_r_hand()
		update_inv_belt()
		update_inv_wear_id()
		update_inv_ears()
		update_inv_s_store()
		update_inv_pockets()
		update_inv_back()
		update_inv_handcuffed()
		update_inv_wear_mask()

	All of these are named after the variable they update from. They are defined at the mob/ level like
	update_clothing was, so you won't cause undefined proc runtimes with usr.update_inv_wear_id() if the usr is a
	corgi etc. Instead, it'll just return without doing any work. So no harm in calling it for corgis and such.


>	There are also these special cases:
		UpdateDamageIcon()	//handles damage overlays for brute/burn damage //(will rename this when I geta round to it)
		update_body()	//Handles updating your mob's icon to reflect their gender/race/complexion etc
		update_hair()	//Handles updating your hair overlay (used to be update_face, but mouth and
																			...eyes were merged into update_body)
		update_targeted() // Updates the target overlay when someone points a gun at you

>	If you need to update all overlays you can use regenerate_icons(). it works exactly like update_clothing used to.


*/

//Human Overlays Indexes/////////
#define MUTANTRACE_LAYER		34
#define DAMAGE_LAYER			33
#define UNIFORM_LAYER			32
#define TAIL_LAYER				31	//bs12 specific. this hack is probably gonna come back to haunt me
#define ID_LAYER				30
#define SHOES_LAYER				29
#define GLOVES_LAYER			28
#define MEDICAL_LAYER			27	//For splint and gauze overlays
#define SUIT_LAYER				26
#define SUIT_GARB_LAYER			25
#define SUIT_SQUAD_LAYER		24
#define GLASSES_LAYER			23
#define BELT_LAYER				22
#define SUIT_STORE_LAYER		21
#define BACK_LAYER				20
#define HAIR_LAYER				19
#define EARS_LAYER				18
#define FACEMASK_LAYER			17
#define HEAD_LAYER				16
#define HEAD_SQUAD_LAYER		15
#define HEAD_GARB_LAYER_2		14	// These actual defines are unused but this space within the overlays list is
#define HEAD_GARB_LAYER_3		13	//  |
#define HEAD_GARB_LAYER_4		12	//  |
#define HEAD_GARB_LAYER_5		11	// End here
#define HEAD_GARB_LAYER			10
#define COLLAR_LAYER			9
#define HANDCUFF_LAYER			8
#define LEGCUFF_LAYER			7
#define L_HAND_LAYER			6
#define R_HAND_LAYER			5
#define BURST_LAYER				4	//Chestburst overlay
#define TARGETED_LAYER			3	//for target sprites when held at gun point, and holo cards.
#define FIRE_LAYER				2	//If you're on fire		//BS12: Layer for the target overlay from weapon targeting system
#define EFFECTS_LAYER			1  //If you're hit by an acid DoT
#define TOTAL_LAYERS			34
//////////////////////////////////

/mob/living/carbon/human
	var/list/overlays_standing[TOTAL_LAYERS]
	var/previous_damage_appearance // store what the body last looked like, so we only have to update it if something changed


/mob/living/carbon/human/apply_overlay(cache_index)
	var/image/I = overlays_standing[cache_index]
	if(I)
		overlays += I

/mob/living/carbon/human/remove_overlay(cache_index)
	if(overlays_standing[cache_index])
		overlays -= overlays_standing[cache_index]
		overlays_standing[cache_index] = null


/mob/living/carbon/human/update_transform()
	if(lying == lying_prev)
		return
	lying_prev = lying
	if(lying)
		var/matrix/M = matrix()
		M.Turn(90)
		M.Scale(size_multiplier)
		M.Translate(1,-6)
		src.transform = M
	else
		var/matrix/M = matrix()
		M.Scale(size_multiplier)
		M.Translate(0, 16 * (size_multiplier - 1))
		src.transform = M


var/global/list/damage_icon_parts = list()

/mob/living/carbon/human/proc/get_damage_icon_part(damage_state, datum/limb/limb)
	var/icon/DI
	var/L_name = limb.icon_name
	if(!damage_icon_parts["[damage_state]_[species.blood_color]_[L_name]"])
		var/brutestate = copytext(damage_state, 1, 2)
		var/burnstate = copytext(damage_state, 2)
		DI = new /icon('icons/mob/humans/dam_human.dmi', "grayscale_[brutestate]")// the damage icon for whole human in grayscale
		DI.Blend(species.blood_color, ICON_MULTIPLY) //coloring with species' blood color
		DI.Blend(new /icon('icons/mob/humans/dam_human.dmi', "burn_[burnstate]"), ICON_OVERLAY)//adding burns
		DI.Blend(new /icon('icons/mob/humans/body_mask.dmi', L_name), ICON_MULTIPLY)		// mask with this organ's pixels
		damage_icon_parts["[damage_state]_[species.blood_color]_[L_name]"] = DI
	else
		DI = damage_icon_parts["[damage_state]_[species.blood_color]_[L_name]"]
	for(var/datum/wound/W in limb.wounds)
		if(W.impact_icon)
			DI.Blend(W.impact_icon, ICON_OVERLAY)

	return DI



//DAMAGE OVERLAYS
//constructs damage icon for each organ from mask * damage field and saves it in our overlays_ lists
/mob/living/carbon/human/UpdateDamageIcon()
	// first check whether something actually changed about damage appearance
	var/damage_appearance = ""

	for(var/datum/limb/O in limbs)
		if(O.status & LIMB_DESTROYED)
			damage_appearance += "d"
		else
			damage_appearance += O.damage_state

	if(damage_appearance == previous_damage_appearance)
		// nothing to do here
		return

	remove_overlay(DAMAGE_LAYER)

	previous_damage_appearance = damage_appearance

	var/icon/standing = new /icon('icons/mob/humans/dam_human.dmi', "00")

	var/image/standing_image = image(icon = standing, layer = -DAMAGE_LAYER)

	// blend the individual damage states with our icons
	for(var/datum/limb/O in limbs)
		var/icon/DI
		var/datum/limb/P = O.parent
		if(!(O.status & LIMB_DESTROYED))
			O.update_icon()
			if(O.damage_state == "00") continue

			DI = get_damage_icon_part(O.damage_state, O)

			standing_image.overlays += DI
		else if(O.has_stump_icon && (!P || !(P.status & LIMB_DESTROYED)))
			DI = new /icon('icons/mob/humans/dam_human.dmi', "stump_[O.icon_name]")

			standing_image.overlays += DI

	overlays_standing[DAMAGE_LAYER]	= standing_image
	apply_overlay(DAMAGE_LAYER)



//BASE MOB SPRITE
/mob/living/carbon/human/proc/update_body(var/force_cache_update = 0)
	var/g = get_gender_name(gender)
	var/has_head = 0


	//CACHING: Generate an index key from visible bodyparts.
	//0 = destroyed, 1 = normal, 2 = robotic

	//Create a new, blank icon for our mob to use.
	if(stand_icon)
		qdel(stand_icon)

	stand_icon = new(species.icon_template ? species.icon_template : 'icons/mob/humans/human.dmi',"blank")

	var/icon_key = "[species.race_key][g][ethnicity]"
	for(var/datum/limb/part in limbs)

		if(istype(part,/datum/limb/head) && !(part.status & LIMB_DESTROYED))
			has_head = 1

		if(part.status & LIMB_DESTROYED)
			icon_key = "[icon_key]0"
		else if(part.status & LIMB_ROBOT)
			icon_key = "[icon_key]2"
		else
			icon_key = "[icon_key]1"

	icon_key = "[icon_key]0000[ethnicity]"

	var/icon/base_icon
	if(!force_cache_update && human_icon_cache[icon_key])
		//Icon is cached, use existing icon.
		base_icon = human_icon_cache[icon_key]

		//log_debug("Retrieved cached mob icon ([icon_key] \icon[human_icon_cache[icon_key]]) for [src].")

	else

	//BEGIN CACHED ICON GENERATION.

		// Why don't we just make skeletons/shadows/golems a species? ~Z
		var/race_icon = species.icobase
		var/deform_icon = species.icobase

		//Robotic limbs are handled in get_icon() so all we worry about are missing or dead limbs.
		//No icon stored, so we need to start with a basic one.
		var/datum/limb/chest = get_limb("chest")
		base_icon = chest.get_icon(race_icon,deform_icon,g)

		for(var/datum/limb/part in limbs)

			var/icon/temp //Hold the bodypart icon for processing.

			if(part.status & LIMB_DESTROYED)
				continue

			if(istype(part, /datum/limb/chest)) //already done above
				continue

			if(istype(part, /datum/limb/groin) || istype(part, /datum/limb/head))
				temp = part.get_icon(race_icon,deform_icon,g)
			else
				temp = part.get_icon(race_icon,deform_icon)

			//That part makes left and right legs drawn topmost and lowermost when human looks WEST or EAST
			//And no change in rendering for other parts (they icon_position is 0, so goes to 'else' part)
			if(part.icon_position&(LEFT|RIGHT))

				var/icon/temp2 = new('icons/mob/humans/human.dmi',"blank")

				temp2.Insert(new/icon(temp,dir=NORTH),dir=NORTH)
				temp2.Insert(new/icon(temp,dir=SOUTH),dir=SOUTH)

				if(!(part.icon_position & LEFT))
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)

				if(!(part.icon_position & RIGHT))
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)

				base_icon.Blend(temp2, ICON_OVERLAY)

				if(part.icon_position & LEFT)
					temp2.Insert(new/icon(temp,dir=EAST),dir=EAST)

				if(part.icon_position & RIGHT)
					temp2.Insert(new/icon(temp,dir=WEST),dir=WEST)

				base_icon.Blend(temp2, ICON_UNDERLAY)

			else

				base_icon.Blend(temp, ICON_OVERLAY)

		human_icon_cache[icon_key] = base_icon

		//log_debug("Generated new cached mob icon ([icon_key] \icon[human_icon_cache[icon_key]]) for [src]. [human_icon_cache.len] cached mob icons.")

	//END CACHED ICON GENERATION.

	stand_icon.Blend(base_icon,ICON_OVERLAY)

	/*
	//Skin colour. Not in cache because highly variable (and relatively benign).
	if(species.flags & HAS_SKIN_COLOR)
		stand_icon.Blend(rgb(r_skin, g_skin, b_skin), ICON_ADD)
	*/

	if(has_head)
		//Eyes
		var/icon/eyes = new/icon('icons/mob/humans/onmob/human_face.dmi', species.eyes)
		eyes.Blend(rgb(r_eyes, g_eyes, b_eyes), ICON_ADD)
		stand_icon.Blend(eyes, ICON_OVERLAY)

		//Mouth	(lipstick!)
		if(lip_style && (species && species.flags & HAS_LIPS))	//skeletons are allowed to wear lipstick no matter what you think, agouri.
			stand_icon.Blend(new/icon('icons/mob/humans/onmob/human_face.dmi', "camo_[lip_style]_s"), ICON_OVERLAY)


	if(species.flags & HAS_UNDERWEAR)

		//Underwear
		if(underwear >0 && underwear < 3)
			var/icon/underwear_icon = new /icon('icons/mob/humans/human.dmi', "cryo[underwear]_[g]_s")
			var/icon/BM = new /icon(icon = 'icons/mob/humans/body_mask.dmi', icon_state = "groin")
			BM.Blend(new /icon('icons/mob/humans/body_mask.dmi', "torso"), ICON_OR)
			for(var/datum/limb/leg/L in limbs)
				var/uniform_icon = "[L.icon_name]"
				if(L.status & LIMB_DESTROYED && !(L.status & LIMB_AMPUTATED))
					uniform_icon += "_removed"
				BM.Blend(new /icon('icons/mob/humans/body_mask.dmi', "[uniform_icon]"), ICON_OR)
			underwear_icon.Blend(BM, ICON_MULTIPLY)
			stand_icon.Blend(underwear_icon, ICON_OVERLAY)

		if(job in ROLES_MARINES) //undoing override
			if(undershirt>0 && undershirt < 5)
				stand_icon.Blend(new /icon('icons/mob/humans/human.dmi', "cryoshirt[undershirt]_s"), ICON_OVERLAY)
		else if(undershirt>0 && undershirt < 5)
			stand_icon.Blend(new /icon('icons/mob/humans/human.dmi', "cryoshirt[undershirt]_s"), ICON_OVERLAY)

	icon = stand_icon

	//tail
	update_tail_showing()



//HAIR OVERLAY
/mob/living/carbon/human/proc/update_hair()
	//Reset our hair
	remove_overlay(HAIR_LAYER)

	var/datum/limb/head/head_organ = get_limb("head")
	if(!head_organ || (head_organ.status & LIMB_DESTROYED))
		return

	//masks and helmets can obscure our hair.
	if((head && (head.flags_inv_hide & HIDEALLHAIR)) || (wear_mask && (wear_mask.flags_inv_hide & HIDEALLHAIR)))
		return

	//base icons
	var/icon/face_standing	= new /icon('icons/mob/humans/human_hair.dmi',"bald_s")

	if(f_style && !(wear_suit && (wear_suit.flags_inv_hide & HIDELOWHAIR)) && !(wear_mask && (wear_mask.flags_inv_hide & HIDELOWHAIR)))
		var/datum/sprite_accessory/facial_hair_style = facial_hair_styles_list[f_style]
		if(facial_hair_style && facial_hair_style.species_allowed && src.species.name in facial_hair_style.species_allowed)
			var/icon/facial_s = new/icon("icon" = facial_hair_style.icon, "icon_state" = "[facial_hair_style.icon_state]_s")
			if(facial_hair_style.do_colouration)
				facial_s.Blend(rgb(r_facial, g_facial, b_facial), ICON_ADD)

			face_standing.Blend(facial_s, ICON_OVERLAY)

	if(h_style && !(head && (head.flags_inv_hide & HIDETOPHAIR)))
		var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
		if(hair_style && src.species.name in hair_style.species_allowed)
			var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
			if(hair_style.do_colouration)
				hair_s.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)

			face_standing.Blend(hair_s, ICON_OVERLAY)

	overlays_standing[HAIR_LAYER] = image("icon"= face_standing, "layer" = -HAIR_LAYER)

	apply_overlay(HAIR_LAYER)



//Call when target overlay should be added/removed
/mob/living/carbon/human/update_targeted()
	remove_overlay(TARGETED_LAYER)
	var/image/I
	if(targeted_by && target_locked)
		I = image("icon" = target_locked)
	else if(!targeted_by && target_locked)
		qdel(target_locked)
		target_locked = null
	if(holo_card_color)
		if(I)
			I.overlays += image("icon" = 'icons/effects/Targeted.dmi', "icon_state" = "holo_card_[holo_card_color]")
		else
			I = image("icon" = 'icons/effects/Targeted.dmi', "icon_state" = "holo_card_[holo_card_color]")
	if(!I)
		return
	I.layer = -TARGETED_LAYER
	overlays_standing[TARGETED_LAYER] = I
	apply_overlay(TARGETED_LAYER)



//Call when someone is gauzed or splinted, or when one of those items are removed
/mob/living/carbon/human/update_med_icon()
	remove_overlay(MEDICAL_LAYER)

	var/icon/standing = new /icon('icons/mob/humans/onmob/med_human.dmi', "blank")

	var/image/standing_image = image(icon = standing)

	// blend the individual damage states with our icons
	for(var/datum/limb/L in limbs)
		for(var/datum/wound/W in L.wounds)
			if(!W.bandaged)
				continue
			if(!W.bandaged_icon)
				var/bandaged_icon_name = "gauze_[L.icon_name]"
				if(L.bandage_icon_amount > 1)
					bandaged_icon_name += "_[rand(1, L.bandage_icon_amount)]"
				W.bandaged_icon = new /icon('icons/mob/humans/onmob/med_human.dmi', "[bandaged_icon_name]")
			standing_image.overlays += W.bandaged_icon
		if(L.status & LIMB_SPLINTED)
			if(!L.splinted_icon)
				var/splinted_icon_name = "splint_[L.icon_name]"
				if(L.splint_icon_amount > 1)
					splinted_icon_name += "_[rand(1, L.splint_icon_amount)]"
				L.splinted_icon = new /icon('icons/mob/humans/onmob/med_human.dmi', "[splinted_icon_name]")
			standing_image.overlays += L.splinted_icon
		else
			L.splinted_icon = null

	if(standing_image)
		standing_image.layer = -MEDICAL_LAYER
		overlays_standing[MEDICAL_LAYER] = standing_image
		apply_overlay(MEDICAL_LAYER)



/* --------------------------------------- */
//For legacy support.
/mob/living/carbon/human/regenerate_icons()
	if(monkeyizing)
		return
	update_inv_w_uniform()
	update_inv_wear_id()
	update_inv_gloves()
	update_inv_glasses()
	update_inv_ears()
	update_inv_shoes()
	update_inv_s_store()
	update_inv_wear_mask()
	update_inv_head()
	update_inv_belt()
	update_inv_back()
	update_inv_wear_suit()
	update_inv_r_hand()
	update_inv_l_hand()
	update_inv_handcuffed()
	update_inv_legcuffed()
	update_inv_pockets()
	update_fire()
	update_burst()
	update_hair()
	update_body()
	update_targeted()
	update_med_icon()
	UpdateDamageIcon()




/* --------------------------------------- */
//vvvvvv UPDATE_INV PROCS vvvvvv

/mob/living/carbon/human/update_inv_w_uniform()
	remove_overlay(UNIFORM_LAYER)
	if(w_uniform)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			w_uniform.screen_loc = hud_used.ui_datum.ui_iclothing
			client.screen += w_uniform

		if(!(wear_suit && wear_suit.flags_inv_hide & HIDEJUMPSUIT))
			var/image/I = w_uniform.get_mob_overlay(src, WEAR_BODY)
			I.layer = -UNIFORM_LAYER
			overlays_standing[UNIFORM_LAYER] = I
			apply_overlay(UNIFORM_LAYER)

	update_inv_wear_id()


/mob/living/carbon/human/update_inv_wear_id()
	remove_overlay(ID_LAYER)
	if(!wear_id)
		return
	if(client && hud_used && hud_used.hud_shown && hud_used.ui_datum)
		wear_id.screen_loc = hud_used.ui_datum.ui_id
		client.screen += wear_id

	if(!wear_id.pinned_on_uniform || (w_uniform && w_uniform.displays_id && !w_uniform.rolled_sleeves))
		var/image/id_overlay = wear_id.get_mob_overlay(src, WEAR_ID)
		id_overlay.layer = -ID_LAYER
		overlays_standing[ID_LAYER]	= id_overlay
		apply_overlay(ID_LAYER)



/mob/living/carbon/human/update_inv_gloves()
	remove_overlay(GLOVES_LAYER)
	var/image/I
	if(gloves)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			gloves.screen_loc = hud_used.ui_datum.ui_gloves
			client.screen += gloves

		if(!(wear_suit && wear_suit.flags_inv_hide & HIDEGLOVES))
			I = gloves.get_mob_overlay(src, WEAR_HANDS)

	else if(hands_blood_color && species.blood_mask)
		I = overlay_image(species.blood_mask, "hands_blood", hands_blood_color, RESET_COLOR)

	if(!I)
		return
	I.layer = -GLOVES_LAYER
	overlays_standing[GLOVES_LAYER]	= I
	apply_overlay(GLOVES_LAYER)


/mob/living/carbon/human/update_inv_glasses()
	remove_overlay(GLASSES_LAYER)
	if(glasses)
		if(client && hud_used &&  hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			glasses.screen_loc = hud_used.ui_datum.ui_glasses
			client.screen += glasses

		var/image/I = glasses.get_mob_overlay(src, WEAR_EYES)
		I.layer = -GLASSES_LAYER
		overlays_standing[GLASSES_LAYER] = I
		apply_overlay(GLASSES_LAYER)



/mob/living/carbon/human/update_inv_ears()
	remove_overlay(EARS_LAYER)
	if(wear_ear)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			wear_ear.screen_loc = hud_used.ui_datum.ui_wear_ear
			client.screen += wear_ear

		var/image/I = wear_ear.get_mob_overlay(src, WEAR_EAR)
		I.layer = -EARS_LAYER
		overlays_standing[EARS_LAYER] = I
		apply_overlay(EARS_LAYER)



/mob/living/carbon/human/update_inv_shoes()
	remove_overlay(SHOES_LAYER)
	var/image/I
	if(shoes)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			shoes.screen_loc = hud_used.ui_datum.ui_shoes
			client.screen += shoes

		if(!((wear_suit && wear_suit.flags_inv_hide & HIDESHOES) || (w_uniform && w_uniform.flags_inv_hide & HIDESHOES)))
			I =  shoes.get_mob_overlay(src, WEAR_FEET)

	else if(feet_blood_color && species.blood_mask)
		I = overlay_image(species.blood_mask, "feet_blood", feet_blood_color, RESET_COLOR)
	if(!I)
		return
	I.layer = -SHOES_LAYER
	overlays_standing[SHOES_LAYER] = I
	apply_overlay(SHOES_LAYER)


/mob/living/carbon/human/update_inv_s_store()
	remove_overlay(SUIT_STORE_LAYER)
	if(s_store)

		if(client && hud_used && hud_used.hud_shown && hud_used.ui_datum)
			s_store.screen_loc = hud_used.ui_datum.ui_sstore1
			client.screen += s_store

		var/image/I	= s_store.get_mob_overlay(src, WEAR_J_STORE)
		I.layer = -SUIT_STORE_LAYER
		overlays_standing[SUIT_STORE_LAYER] = I
		apply_overlay(SUIT_STORE_LAYER)


#define MAX_HEAD_GARB_ITEMS 5

/mob/living/carbon/human/update_inv_head()
	remove_overlay(HEAD_LAYER)
	remove_overlay(HEAD_SQUAD_LAYER)
	for(var/i in HEAD_GARB_LAYER to (HEAD_GARB_LAYER + MAX_HEAD_GARB_ITEMS - 1))
		remove_overlay(i)

	if(head)

		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			head.screen_loc = hud_used.ui_datum.ui_head
			client.screen += head

		var/image/I = head.get_mob_overlay(src, WEAR_HEAD)
		I.layer = -HEAD_LAYER
		overlays_standing[HEAD_LAYER] = I
		apply_overlay(HEAD_LAYER)

		if(istype(head, /obj/item/clothing/head/helmet/marine))
			var/obj/item/clothing/head/helmet/marine/marine_helmet = head
			if(assigned_squad && marine_helmet.flags_marine_helmet & HELMET_SQUAD_OVERLAY)
				var/datum/squad/S = assigned_squad
				var/leader = S.squad_leader == src
				if(S.color <= helmetmarkings.len)
					var/image/J = leader? helmetmarkings_sql[S.color] : helmetmarkings[S.color]
					J.layer = -HEAD_SQUAD_LAYER
					overlays_standing[HEAD_SQUAD_LAYER] = J
					apply_overlay(HEAD_SQUAD_LAYER)

			var/num_helmet_overlays = 0
			for(var/i in 1 to marine_helmet.helmet_overlays.len)
				// Add small numbers to the head garb layer so we don't have a layer conflict
				// the i-1 bit is to make it 0-based, not 1-based like BYOND wants
				overlays_standing[HEAD_GARB_LAYER + (i-1)] = image('icons/mob/humans/onmob/helmet_garb.dmi', src, marine_helmet.helmet_overlays[i])
				num_helmet_overlays++

			// null out the rest of the space allocated for helmet overlays
			// God I hate 1-based indexing
			for(var/i in num_helmet_overlays+1 to MAX_HEAD_GARB_ITEMS)
				overlays_standing[HEAD_GARB_LAYER + (i-1)] = null
				
			for(var/i in HEAD_GARB_LAYER to (HEAD_GARB_LAYER + MAX_HEAD_GARB_ITEMS - 1))
				apply_overlay(i)

#undef MAX_HEAD_GARB_ITEMS


/mob/living/carbon/human/update_inv_belt()
	remove_overlay(BELT_LAYER)
	if(!belt)
		return
	if(client && hud_used && hud_used.hud_shown && hud_used.ui_datum)
		belt.screen_loc = hud_used.ui_datum.ui_belt
		client.screen += belt
	var/image/I = belt.get_mob_overlay(src, WEAR_WAIST)
	I.layer = -BELT_LAYER
	overlays_standing[BELT_LAYER] = I
	apply_overlay(BELT_LAYER)



/mob/living/carbon/human/update_inv_wear_suit()
	remove_overlay(SUIT_LAYER)
	remove_overlay(SUIT_SQUAD_LAYER)
	remove_overlay(SUIT_GARB_LAYER)

	if(wear_suit)
		if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
			wear_suit.screen_loc = hud_used.ui_datum.ui_oclothing
			client.screen += wear_suit

		var/image/I = wear_suit.get_mob_overlay(src, WEAR_JACKET)
		I.layer = -SUIT_LAYER
		overlays_standing[SUIT_LAYER] = I
		apply_overlay(SUIT_LAYER)

		if(istype(wear_suit, /obj/item/clothing/suit/storage/marine))
			var/obj/item/clothing/suit/storage/marine/marine_armor = wear_suit
			if(marine_armor.flags_marine_armor & ARMOR_SQUAD_OVERLAY)
				if(assigned_squad)
					var/datum/squad/S = assigned_squad
					var/leader = S.squad_leader == src
					if(S.color <= helmetmarkings.len)
						var/image/J = leader? armormarkings_sql[S.color] : armormarkings[S.color]
						J.layer = -SUIT_SQUAD_LAYER
						overlays_standing[SUIT_SQUAD_LAYER] = J
						apply_overlay(SUIT_SQUAD_LAYER)

			if(marine_armor.armor_overlays.len)
				var/image/K
				var/image/IMG
				for(var/i in marine_armor.armor_overlays)
					K = marine_armor.armor_overlays[i]
					if(K)
						if(!IMG)
							IMG = image(K.icon,src,K.icon_state, "layer"= -SUIT_GARB_LAYER)
						else
							IMG.overlays += image(K.icon,src,K.icon_state, "layer"= -SUIT_GARB_LAYER)
				if(IMG)
					overlays_standing[SUIT_GARB_LAYER] = IMG
					apply_overlay(SUIT_GARB_LAYER)

		update_tail_showing()
	else
		update_tail_showing()
		update_inv_w_uniform()
		update_inv_shoes()
		update_inv_gloves()

	update_collar()



/mob/living/carbon/human/update_inv_pockets()
	if(!(client && hud_used && hud_used.hud_shown && hud_used.ui_datum))
		return

	if(l_store)
		l_store.screen_loc = hud_used.ui_datum.ui_storage1
		client.screen += l_store
	if(r_store)
		r_store.screen_loc = hud_used.ui_datum.ui_storage2
		client.screen += r_store


/mob/living/carbon/human/update_inv_wear_mask()
	remove_overlay(FACEMASK_LAYER)
	if(!wear_mask)
		return
	if(client && hud_used && hud_used.hud_shown && hud_used.inventory_shown && hud_used.ui_datum)
		wear_mask.screen_loc = hud_used.ui_datum.ui_mask
		client.screen += wear_mask

	if(!(head && head.flags_inv_hide & HIDEMASK))
		var/image/I = wear_mask.get_mob_overlay(src, WEAR_FACE)
		I.layer = -FACEMASK_LAYER
		overlays_standing[FACEMASK_LAYER] = I
		apply_overlay(FACEMASK_LAYER)


/mob/living/carbon/human/update_inv_back()
	remove_overlay(BACK_LAYER)
	if(!back)
		return
	if(client && hud_used && hud_used.hud_shown && hud_used.ui_datum)
		back.screen_loc = hud_used.ui_datum.ui_back
		client.screen += back

	var/image/I = back.get_mob_overlay(src, WEAR_BACK)
	I.layer = -BACK_LAYER
	overlays_standing[BACK_LAYER] = I
	apply_overlay(BACK_LAYER)


/mob/living/carbon/human/update_inv_handcuffed()
	remove_overlay(HANDCUFF_LAYER)
	if(!handcuffed)
		return
	var/image/I = handcuffed.get_mob_overlay(src, WEAR_HANDCUFFS)
	I.layer = -HANDCUFF_LAYER
	overlays_standing[HANDCUFF_LAYER] = I
	apply_overlay(HANDCUFF_LAYER)



/mob/living/carbon/human/update_inv_legcuffed()
	remove_overlay(LEGCUFF_LAYER)
	if(!legcuffed)
		return
	var/image/I = legcuffed.get_mob_overlay(src, WEAR_LEGCUFFS)
	I.layer = -LEGCUFF_LAYER
	overlays_standing[LEGCUFF_LAYER] = I
	apply_overlay(LEGCUFF_LAYER)


/mob/living/carbon/human/update_inv_r_hand()
	remove_overlay(R_HAND_LAYER)
	if(!r_hand)
		return
	if(client && hud_used && hud_used.hud_version != HUD_STYLE_NOHUD && hud_used.ui_datum)
		client.screen += r_hand
		r_hand.screen_loc = hud_used.ui_datum.ui_rhand

	var/image/I = r_hand.get_mob_overlay(src, WEAR_R_HAND)
	I.layer = -R_HAND_LAYER
	overlays_standing[R_HAND_LAYER] = I
	apply_overlay(R_HAND_LAYER)



/mob/living/carbon/human/update_inv_l_hand()
	remove_overlay(L_HAND_LAYER)
	if(!l_hand)
		return
	if(client && hud_used && hud_used.hud_version != HUD_STYLE_NOHUD && hud_used.ui_datum)
		client.screen += l_hand
		l_hand.screen_loc = hud_used.ui_datum.ui_lhand
	var/image/I = l_hand.get_mob_overlay(src, WEAR_L_HAND)
	I.layer = -L_HAND_LAYER
	overlays_standing[L_HAND_LAYER] = I
	apply_overlay(L_HAND_LAYER)



/mob/living/carbon/human/proc/update_tail_showing()
	remove_overlay(TAIL_LAYER)

	var/species_tail = species.get_tail(src)

	if(species_tail && !(wear_suit && wear_suit.flags_inv_hide & HIDETAIL))
		var/icon/tail_s = get_tail_icon()
		overlays_standing[TAIL_LAYER] = image(tail_s, icon_state = "[species_tail]_s", "layer" = -TAIL_LAYER)
		apply_overlay(TAIL_LAYER)


/mob/living/carbon/human/proc/get_tail_icon()
	var/icon_key = "[species.race_key][r_skin][g_skin][b_skin][r_hair][g_hair][b_hair]"
	var/icon/tail_icon = tail_icon_cache[icon_key]
	if(!tail_icon)
		//generate a new one
		tail_icon = icon('icons/effects/species.dmi', "[species.get_tail(src)]")
		tail_icon_cache[icon_key] = tail_icon

	return tail_icon


//Adds a collar overlay above the helmet layer if the suit has one
//	Suit needs an identically named sprite in icons/mob/collar.dmi
/mob/living/carbon/human/proc/update_collar()
	remove_overlay(COLLAR_LAYER)
	if(!istype(wear_suit,/obj/item/clothing/suit))
		return
	var/obj/item/clothing/suit/S = wear_suit
	var/image/I = S.get_collar()
	if(I)
		I.layer = -COLLAR_LAYER
		overlays_standing[COLLAR_LAYER]	= I
		apply_overlay(COLLAR_LAYER)



// Used mostly for creating head items
/mob/living/carbon/human/proc/generate_head_icon()
//gender no longer matters for the mouth, although there should probably be seperate base head icons.
//	var/g = "m"
//	if(gender == FEMALE)	g = "f"

	//base icons
	var/icon/face_lying	= new /icon('icons/mob/humans/human_hair.dmi',"bald_l")

	if(f_style)
		var/datum/sprite_accessory/facial_hair_style = facial_hair_styles_list[f_style]
		if(facial_hair_style)
			var/icon/facial_l = new/icon("icon" = facial_hair_style.icon, "icon_state" = "[facial_hair_style.icon_state]_l")
			facial_l.Blend(rgb(r_facial, g_facial, b_facial), ICON_ADD)
			face_lying.Blend(facial_l, ICON_OVERLAY)

	if(h_style)
		var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
		if(hair_style)
			var/icon/hair_l = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_l")
			hair_l.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)
			face_lying.Blend(hair_l, ICON_OVERLAY)

	//Eyes
	// Note: These used to be in update_face(), and the fact they're here will make it difficult to create a disembodied head
	var/icon/eyes_l = new/icon('icons/mob/humans/onmob/human_face.dmi', "eyes_l")
	eyes_l.Blend(rgb(r_eyes, g_eyes, b_eyes), ICON_ADD)
	face_lying.Blend(eyes_l, ICON_OVERLAY)

	if(lip_style)
		face_lying.Blend(new/icon('icons/mob/humans/onmob/human_face.dmi', "lips_[lip_style]_l"), ICON_OVERLAY)

	var/image/face_lying_image = image(icon = face_lying)
	return face_lying_image


/mob/living/carbon/human/update_burst()
	remove_overlay(BURST_LAYER)
	var/image/standing
	switch(chestburst)
		if(1)
			standing = image("icon" = 'icons/mob/xenos/Effects.dmi',"icon_state" = "burst_stand", "layer" = -BURST_LAYER)
		if(2)
			standing = image("icon" = 'icons/mob/xenos/Effects.dmi',"icon_state" = "bursted_stand", "layer" = -BURST_LAYER)
		else
			return
	overlays_standing[BURST_LAYER] = standing
	apply_overlay(BURST_LAYER)


/mob/living/carbon/human/update_fire()
	remove_overlay(FIRE_LAYER)
	if(!on_fire)
		return
	var/image/I
	switch(fire_stacks)
		if(1 to 14)
			I = image("icon"='icons/mob/humans/onmob/OnFire.dmi', "icon_state"="Standing_weak", "layer"= -FIRE_LAYER)
		if(15 to INFINITY)
			I = image("icon"='icons/mob/humans/onmob/OnFire.dmi', "icon_state"="Standing_medium", "layer"= -FIRE_LAYER)
		else
			return
	overlays_standing[FIRE_LAYER] = I
	apply_overlay(FIRE_LAYER)


/mob/living/carbon/human/proc/update_effects()
	remove_overlay(EFFECTS_LAYER)

	var/image/I
	for(var/datum/effects/E in effects_list)
		if(E.icon_path && E.mob_icon_state_path)
			if(!I)
				I = image("icon" = E.icon_path, "icon_state" = E.mob_icon_state_path, "layer"= -EFFECTS_LAYER)
			else
				I.overlays += image("icon" = E.icon_path, "icon_state" = E.mob_icon_state_path, "layer"= -EFFECTS_LAYER)
	if(!I)
		return
	overlays_standing[EFFECTS_LAYER] = I
	apply_overlay(EFFECTS_LAYER)


//Human Overlays Indexes/////////
#undef MUTANTRACE_LAYER
#undef DAMAGE_LAYER
#undef UNIFORM_LAYER
#undef TAIL_LAYER
#undef ID_LAYER
#undef SHOES_LAYER
#undef GLOVES_LAYER
#undef EARS_LAYER
#undef SUIT_LAYER
#undef GLASSES_LAYER
#undef FACEMASK_LAYER
#undef BELT_LAYER
#undef SUIT_STORE_LAYER
#undef BACK_LAYER
#undef HAIR_LAYER
#undef HEAD_LAYER
#undef COLLAR_LAYER
#undef HANDCUFF_LAYER
#undef LEGCUFF_LAYER
#undef L_HAND_LAYER
#undef R_HAND_LAYER
#undef TARGETED_LAYER
#undef FIRE_LAYER
#undef BURST_LAYER
#undef TOTAL_LAYERS
