"""Seed catalogue for the demo store.

Kept in code rather than a SQL fixture so the same data can be loaded into a
fresh local Postgres, a throwaway test database, or RDS after a deploy.
"""

CATEGORIES = [
    {
        "slug": "chalkboards",
        "name": "Chalkboards",
        "tagline": "Real slate and painted steel for chalk that squeaks the right way.",
        "sort_order": 10,
    },
    {
        "slug": "whiteboards",
        "name": "Whiteboards",
        "tagline": "Magnetic dry-erase surfaces sized for standups and long arguments.",
        "sort_order": 20,
    },
    {
        "slug": "glass-boards",
        "name": "Glass boards",
        "tagline": "Tempered glass that never ghosts, however long the diagram lives.",
        "sort_order": 30,
    },
    {
        "slug": "cork",
        "name": "Cork & pinboards",
        "tagline": "For the parts of a plan that need a pin instead of a pen.",
        "sort_order": 40,
    },
    {
        "slug": "easels",
        "name": "Easels & stands",
        "tagline": "Portable surfaces for rooms that were not designed for thinking.",
        "sort_order": 50,
    },
    {
        "slug": "paper",
        "name": "Paper & pads",
        "tagline": "Draft pads and sketchbooks for the version nobody else sees.",
        "sort_order": 60,
    },
    {
        "slug": "accessories",
        "name": "Accessories",
        "tagline": "Chalk, markers, erasers and magnets that outlive the board.",
        "sort_order": 70,
    },
]

PRODUCTS = [
    # --- chalkboards ---------------------------------------------------
    {
        "slug": "slate-classic-900",
        "name": "Slate Classic 900",
        "category": "chalkboards",
        "surface": "chalk",
        "price_cents": 12900,
        "width_mm": 900,
        "height_mm": 600,
        "summary": "Framed natural slate in oiled ash. The default board.",
        "description": (
            "A single sheet of quarried slate set in an oiled ash frame. Slate is heavy and "
            "unhurried: it takes chalk with almost no dust, wipes clean with a damp cloth, and "
            "looks better after five years than it did on day one. Ships with two wall anchors "
            "and a full-width chalk rail."
        ),
        "stock": 24,
        "featured": True,
        "accent": "#2f4f4a",
    },
    {
        "slug": "slate-classic-1200",
        "name": "Slate Classic 1200",
        "category": "chalkboards",
        "surface": "chalk",
        "price_cents": 18900,
        "width_mm": 1200,
        "height_mm": 900,
        "summary": "The Classic, scaled up for a wall that hosts arguments.",
        "description": (
            "Same quarried slate and oiled ash frame as the 900, with enough width for a system "
            "diagram and the objections next to it. The frame is mitred and glued rather than "
            "stapled, which is why it survives being re-hung between offices."
        ),
        "stock": 15,
        "featured": True,
        "accent": "#243b3a",
    },
    {
        "slug": "studio-slate-xl",
        "name": "Studio Slate XL",
        "category": "chalkboards",
        "surface": "chalk",
        "price_cents": 42500,
        "width_mm": 1800,
        "height_mm": 1200,
        "summary": "Wall-filling slate for teams that draw before they type.",
        "description": (
            "Two metres of horizontal thinking. The XL is mounted on a steel subframe so it can "
            "hang on plasterboard without a stud on every corner, and the surface is honed rather "
            "than polished so chalk lines stay crisp at the back of a room."
        ),
        "stock": 6,
        "featured": True,
        "accent": "#1f3330",
    },
    {
        "slug": "pocket-slate-a5",
        "name": "Pocket Slate A5",
        "category": "chalkboards",
        "surface": "chalk",
        "price_cents": 2400,
        "width_mm": 210,
        "height_mm": 148,
        "summary": "A handheld slate for one idea at a time.",
        "description": (
            "The board equivalent of a sticky note, except it lasts a decade. Bevelled edges, a "
            "hole for a lanyard, and a surface on both sides. Popular for labelling shelves, "
            "planters and the office fridge."
        ),
        "stock": 120,
        "featured": False,
        "accent": "#37504b",
    },
    # --- whiteboards -----------------------------------------------------
    {
        "slug": "nib-dry-erase-1200",
        "name": "Nib Dry-Erase 1200",
        "category": "whiteboards",
        "surface": "dry-erase",
        "price_cents": 15900,
        "width_mm": 1200,
        "height_mm": 900,
        "summary": "Porcelain-on-steel, magnetic, genuinely ghost-free.",
        "description": (
            "Porcelain enamel fired onto a steel core. It costs more than a melamine board and "
            "then refuses to ghost, stain or dent for the rest of its life. Fully magnetic, with "
            "an aluminium tray that takes markers and the magnet kit."
        ),
        "stock": 30,
        "featured": True,
        "accent": "#3d6ea8",
    },
    {
        "slug": "nib-dry-erase-1800",
        "name": "Nib Dry-Erase 1800",
        "category": "whiteboards",
        "surface": "dry-erase",
        "price_cents": 27900,
        "width_mm": 1800,
        "height_mm": 1200,
        "summary": "The standup-sized porcelain board.",
        "description": (
            "Wide enough for a swimlane diagram that does not need to be erased halfway through. "
            "Same porcelain-on-steel surface as the 1200, shipped in a crate rather than a box "
            "because the corners are the part that usually arrives damaged."
        ),
        "stock": 11,
        "featured": False,
        "accent": "#33608f",
    },
    {
        "slug": "roll-up-dry-erase-sheet",
        "name": "Roll-Up Dry-Erase Sheet",
        "category": "whiteboards",
        "surface": "dry-erase",
        "price_cents": 4900,
        "width_mm": 2000,
        "height_mm": 1200,
        "summary": "Two square metres of board you can post to someone.",
        "description": (
            "A static-cling sheet that hangs on any smooth wall with no adhesive, no fixings and "
            "no deposit dispute. Rolls back into its tube for the next room. Not magnetic, and "
            "that is the trade."
        ),
        "stock": 64,
        "featured": False,
        "accent": "#4a7fb5",
    },
    # --- glass -----------------------------------------------------------
    {
        "slug": "clarity-glass-board",
        "name": "Clarity Glass Board",
        "category": "glass-boards",
        "surface": "glass",
        "price_cents": 31900,
        "width_mm": 1200,
        "height_mm": 900,
        "summary": "Tempered glass on standoffs. Erases to nothing, every time.",
        "description": (
            "4mm tempered glass with a back-painted face, floated 20mm off the wall on brushed "
            "steel standoffs. Glass is the only surface that genuinely returns to blank, which "
            "matters when the same board carries a different diagram every day."
        ),
        "stock": 9,
        "featured": True,
        "accent": "#6f7f86",
    },
    {
        "slug": "clarity-glass-desk-pad",
        "name": "Clarity Glass Desk Pad",
        "category": "glass-boards",
        "surface": "glass",
        "price_cents": 8900,
        "width_mm": 600,
        "height_mm": 400,
        "summary": "A writable glass pad that lives under your keyboard.",
        "description": (
            "For the diagram that is only for you. Sits flat on the desk on silicone feet, takes "
            "any dry-erase marker, and doubles as a mouse surface. The back face is sandblasted "
            "so it does not slide."
        ),
        "stock": 48,
        "featured": False,
        "accent": "#7d8c92",
    },
    # --- cork ------------------------------------------------------------
    {
        "slug": "cork-pinboard-900",
        "name": "Cork Pinboard 900",
        "category": "cork",
        "surface": "cork",
        "price_cents": 7400,
        "width_mm": 900,
        "height_mm": 600,
        "summary": "Dense natural cork in an ash frame. Takes a pin forever.",
        "description": (
            "12mm of compressed natural cork, not the 4mm veneer over fibreboard that gives cork "
            "a bad name. Pins go in cleanly and the holes close behind them, so the surface still "
            "looks intact after a year of moving cards around."
        ),
        "stock": 37,
        "featured": False,
        "accent": "#b5793f",
    },
    {
        "slug": "cork-tile-set",
        "name": "Cork Tile Set",
        "category": "cork",
        "surface": "cork",
        "price_cents": 3600,
        "width_mm": 300,
        "height_mm": 300,
        "summary": "Four self-adhesive tiles for a board the shape of your wall.",
        "description": (
            "Four 300mm squares with a peel-and-stick back, so a pinboard can grow one tile at a "
            "time and stop where the wall does. Butt them together for a continuous surface or "
            "leave a gap and call it design."
        ),
        "stock": 90,
        "featured": False,
        "accent": "#c08a51",
    },
    # --- easels ------------------------------------------------------------
    {
        "slug": "studio-a-frame-easel",
        "name": "Studio A-Frame Easel",
        "category": "easels",
        "surface": "chalk",
        "price_cents": 21500,
        "width_mm": 700,
        "height_mm": 1000,
        "summary": "Double-sided chalkboard on a folding beech frame.",
        "description": (
            "Two chalk surfaces back to back on a beech A-frame that folds flat in one movement. "
            "Steady enough to write on hard, light enough to carry between rooms in one hand. "
            "The hinge is brass, because the plastic ones are what fail."
        ),
        "stock": 14,
        "featured": False,
        "accent": "#2b463f",
    },
    {
        "slug": "flipchart-easel",
        "name": "Flipchart Easel & Pad",
        "category": "easels",
        "surface": "paper",
        "price_cents": 17900,
        "width_mm": 700,
        "height_mm": 1000,
        "summary": "Height-adjustable stand with a magnetic dry-erase back.",
        "description": (
            "Takes a standard flipchart pad on the front and works as a small magnetic whiteboard "
            "once the paper is gone. Telescoping legs, rubberised feet, and a pad of 40 gridded "
            "sheets included so the first session is not a shopping trip."
        ),
        "stock": 19,
        "featured": False,
        "accent": "#8a7f6d",
    },
    # --- paper --------------------------------------------------------------
    {
        "slug": "draft-pad-a1",
        "name": "Draft Pad A1",
        "category": "paper",
        "surface": "paper",
        "price_cents": 3200,
        "width_mm": 841,
        "height_mm": 594,
        "summary": "50 sheets of 90gsm layout paper, gridded 20mm.",
        "description": (
            "Big enough to draw a whole architecture on one sheet, thin enough to trace the next "
            "revision through it. Gummed along the top edge so a sheet tears off straight."
        ),
        "stock": 75,
        "featured": False,
        "accent": "#c9bda4",
    },
    {
        "slug": "grid-sketchbook-a4",
        "name": "Grid Sketchbook A4",
        "category": "paper",
        "surface": "paper",
        "price_cents": 1800,
        "width_mm": 297,
        "height_mm": 210,
        "summary": "Lay-flat sketchbook, 120 pages of 5mm grid.",
        "description": (
            "Sewn binding so it opens flat on a desk without being broken in, 100gsm paper that "
            "does not show ink through, and a grid light enough to ignore when you want to."
        ),
        "stock": 140,
        "featured": False,
        "accent": "#b9ae95",
    },
    # --- accessories -----------------------------------------------------------
    {
        "slug": "dustless-chalk-set",
        "name": "Dustless Chalk Set",
        "category": "accessories",
        "surface": "none",
        "price_cents": 1200,
        "width_mm": None,
        "height_mm": None,
        "summary": "12 colours of low-dust chalk in a tin.",
        "description": (
            "Hard-pressed chalk that writes a fine line and leaves the tray almost clean. Twelve "
            "colours, in a hinged tin that fits the rail on any of our framed boards."
        ),
        "stock": 200,
        "featured": True,
        "accent": "#d8cfc0",
    },
    {
        "slug": "low-odour-marker-set",
        "name": "Low-Odour Marker Set",
        "category": "accessories",
        "surface": "none",
        "price_cents": 1600,
        "width_mm": None,
        "height_mm": None,
        "summary": "Eight dry-erase markers with a chisel tip.",
        "description": (
            "Alcohol-based ink that erases from glass and porcelain without a smear, in eight "
            "colours that stay distinguishable from the back of the room. Chisel tip gives a "
            "3mm line on its edge and 6mm on its face."
        ),
        "stock": 180,
        "featured": False,
        "accent": "#4c6ea8",
    },
    {
        "slug": "microfibre-eraser-block",
        "name": "Microfibre Eraser Block",
        "category": "accessories",
        "surface": "none",
        "price_cents": 900,
        "width_mm": None,
        "height_mm": None,
        "summary": "Magnetic eraser with washable microfibre pads.",
        "description": (
            "A weighted block that sticks to any steel board, with four replaceable microfibre "
            "pads. The pads go in the washing machine, which is the whole point: felt erasers "
            "just move old ink around."
        ),
        "stock": 160,
        "featured": False,
        "accent": "#6e7b83",
    },
    {
        "slug": "magnetic-diagram-kit",
        "name": "Magnetic Diagram Kit",
        "category": "accessories",
        "surface": "none",
        "price_cents": 2900,
        "width_mm": None,
        "height_mm": None,
        "summary": "Boxes, arrows and labels that move without being redrawn.",
        "description": (
            "48 magnetic pieces - rounded boxes, straight and elbowed arrows, and blank labels "
            "you can write on and wipe. For the stage of a diagram where the shape of the thing "
            "is still moving."
        ),
        "stock": 55,
        "featured": True,
        "accent": "#a8563d",
    },
    {
        "slug": "board-care-kit",
        "name": "Board Care Kit",
        "category": "accessories",
        "surface": "none",
        "price_cents": 2200,
        "width_mm": None,
        "height_mm": None,
        "summary": "Cleaner, conditioner and two cloths for slate and glass.",
        "description": (
            "A 250ml surface cleaner that will not haze glass, a slate conditioner that restores "
            "the matte finish, and two lint-free cloths. Quarterly use is the difference between "
            "a board that lasts five years and one that lasts twenty."
        ),
        "stock": 85,
        "featured": False,
        "accent": "#5c6f63",
    },
]
