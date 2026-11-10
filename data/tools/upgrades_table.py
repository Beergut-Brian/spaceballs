"""The upgrade table: the one place Content edits names, kinds, tiers and multipliers.
`make_upgrades.py` writes data/upgrades/<id>.tres from it; `draw_icons.py` reads the ids.
Columns: id, name, kind, tier, power_mult, description, windup_anim, kick_sfx (both optional)."""

UPGRADES = [
    # --- normal: 60 % of cards, x1.6 to x1.9 -------------------------------------------------
    ("big_boot", "Big Boot", "normal", 1, 1.70, "A boot the size of a bathtub. Plenty of room for the foot.", "", ""),
    ("spring_shoes", "Spring Shoes", "normal", 1, 1.70, "Boing on the way in, boing on the way out.", "", ""),
    ("lucky_sock", "Lucky Sock", "normal", 1, 1.65, "Never washed. That's where the luck lives.", "", ""),
    ("trampoline_tee", "Trampoline Tee", "normal", 1, 1.65, "The ball sits on a tiny trampoline and is very excited about it.", "", ""),
    ("helium_ball", "Helium Ball", "normal", 1, 1.65, "Fill the ball with balloon gas. It wants to go up anyway.", "", ""),
    ("sweatband", "Sweatband", "normal", 1, 1.60, "Looks sporty. Is sporty. Smells sporty.", "", ""),
    ("rocket_boots", "Rocket Boots", "normal", 2, 1.80, "Boots with little rockets on the heels. Mind the lawn.", "", ""),
    ("super_strength", "Super Strength", "normal", 2, 1.75, "Lifts a dumbbell with one hand. Kicks with the other foot.", "", ""),
    ("running_start", "Running Start", "normal", 2, 1.75, "A stopwatch on a string. Ready, steady, KICK.", "", ""),
    ("coachs_whistle", "Coach's Whistle", "normal", 2, 1.75, "Tweet! The ball listens to the coach.", "", ""),
    ("super_cape", "Super Cape", "normal", 2, 1.80, "A cape made from a bath towel. Flaps heroically.", "", ""),
    ("propeller_cap", "Propeller Cap", "normal", 2, 1.75, "The propeller spins so fast the whole kick gets lighter.", "", ""),
    ("foam_finger", "Foam Finger", "normal", 2, 1.70, "Number one kicker, says the giant foam hand.", "", ""),
    ("giant_foot", "Giant Foot", "normal", 3, 1.90, "One normal foot. One foot the size of a sofa.", "", ""),
    ("knee_pads", "Bouncy Knee Pads", "normal", 3, 1.85, "Rubber knees. Every kick comes back with a boing.", "", ""),
    ("wind_up_key", "Wind-Up Key", "normal", 3, 1.85, "Wind the kicker up like a toy, then let go.", "", ""),
    # --- strong: 20 %, x2.3 to x2.8 ----------------------------------------------------------
    ("dad_strength", "Dad Strength", "strong", 1, 2.30, "A tool belt, a mug of coffee and the power of every dad ever.", "", ""),
    ("slingshot_buddy", "Slingshot Buddy", "strong", 1, 2.40, "The other kicker holds the slingshot. Pull back... further...", "", ""),
    ("moon_gravity", "Moon Gravity", "strong", 1, 2.35, "A little moon follows you around and makes everything floaty.", "", ""),
    ("cannon_leg", "Cannon Leg", "strong", 2, 2.55, "A leg that is also a cannon. Kaboom, but friendly.", "", ""),
    ("pogo_legs", "Pogo Legs", "strong", 2, 2.50, "Two pogo sticks where the legs used to be.", "", ""),
    ("tornado_spin", "Tornado Spin", "strong", 2, 2.55, "Spin so fast you become a small, polite tornado.", "", ""),
    ("jetpack", "Jetpack", "strong", 2, 2.60, "Two fizzing rockets on the back. Strap in.", "", ""),
    ("volcano_boots", "Volcano Boots", "strong", 2, 2.50, "Each boot is a tiny volcano. Hot feet, huge kick.", "", ""),
    ("kangaroo_tail", "Kangaroo Tail", "strong", 2, 2.45, "Sit on the tail, bounce, kick. Ask any kangaroo.", "", ""),
    ("turbo_fan", "Turbo Fan", "strong", 3, 2.80, "A fan the size of a fridge strapped to the back. Hair everywhere.", "", ""),
    ("thunder_hat", "Thunder Hat", "strong", 3, 2.75, "A grumpy little storm cloud. The kick comes with lightning.", "", ""),
    # --- joke: 12 %, x1.0 to x1.3, very funny ------------------------------------------------
    ("tiny_hat", "Tiny Hat", "joke", 1, 1.10, "A very small hat. Very dignified.", "", ""),
    ("extra_shoes", "Extra Shoes", "joke", 1, 1.15, "Now with four shoes. Nobody knows where the extra feet came from.", "", ""),
    ("mustache", "Mustache", "joke", 1, 1.05, "A magnificent mustache. Strength unknown, style enormous.", "", ""),
    ("honk_horn_shoes", "Honk Horn Shoes", "joke", 1, 1.15, "Every step honks. Every kick HONKS.", "", ""),
    ("confetti_kick", "Confetti Kick", "joke", 2, 1.20, "Pop! The kick comes with a party.", "", ""),
    ("balloon_animal_ball", "Balloon Animal Ball", "joke", 2, 1.15, "A balloon dog for company. It squeaks when you kick.", "", ""),
    ("opera_kick", "Opera Kick", "joke", 2, 1.25, "Hold the high note through the whole wind-up. LAAAA!", "", ""),
    ("rubber_chicken", "Rubber Chicken", "joke", 2, 1.10, "It does nothing. It squawks anyway.", "", ""),
    ("duck_floatie", "Duck Floatie", "joke", 3, 1.20, "Ready for the pool. The pool is not here.", "", ""),
    ("googly_eyes", "Googly Eyes", "joke", 3, 1.00, "Two enormous wobbly eyes stuck on the tummy. No help at all.", "", ""),
    # --- curse: 8 %, x0.1 to x0.3, next kick only, look tempting -----------------------------
    ("kiss_the_frog", "Kiss the Frog", "curse", 1, 0.20, "Mwah. Ribbit. One round as a frog.", "", ""),
    ("banana_peel", "Banana Peel", "curse", 1, 0.25, "Whoops, a banana peel right by the tee. Slip, flip, plop.", "", ""),
    ("sneeze", "Sneeze", "curse", 1, 0.30, "Ah... ahh... AHHH-CHOO! Right on the kick.", "", ""),
    ("shoelaces_tied", "Shoelaces Tied", "curse", 2, 0.15, "Somebody tied your laces together. Hop, hop, bonk.", "", ""),
    ("too_much_lunch", "Too Much Lunch", "curse", 2, 0.20, "Three sandwiches and a pie. Too full to kick.", "", ""),
    ("butterfly", "Butterfly", "curse", 2, 0.25, "Ooh, a butterfly! The kick can wait.", "", ""),
    ("hiccups", "Hiccups", "curse", 3, 0.30, "Hic! The kick goes hic-wards.", "", ""),
]

KIND_RANGES = {"normal": (1.6, 1.9), "strong": (2.3, 2.8), "joke": (1.0, 1.3), "curse": (0.1, 0.3)}
