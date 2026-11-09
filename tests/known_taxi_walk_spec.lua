-- The reported Stormwind to Wailing Caverns journey (#465): a flight point the client has reported, Booty Bay,
-- makes the route fly and sail instead of running the whole way. With no flight point known, the same journey
-- walks to the boat, and the plan says an unknown flight point would have shortened it.
local ns = {}
assert(loadfile("Locales/enUS.lua"))("ShortestPathForever", ns)
for _, file in ipairs({
	"Transport/Model.lua",
	"Routing/Planner.lua",
	"Data/Routes.lua",
	"Data/Transports.lua",
	"Data/Taxi.lua",
	"Data/Portals.lua",
	"Data/Teleports.lua",
	"Data/Walks.lua",
}) do
	assert(loadfile(file))("ShortestPathForever", ns)
end

local function Plan(from, to, known, faction)
	return ns.Planner.Plan({
		from = from,
		to = to,
		now = 0,
		docks = ns.Docks,
		routes = ns.Routes,
		taxiNodes = ns.TaxiNodes,
		taxiPaths = ns.TaxiPaths,
		portals = ns.Portals,
		landmasses = ns.Landmasses,
		baked = ns.Walks,
		faction = faction or "Alliance",
		otherFaction = false,
		walkSpeed = 7,
		taxiKnown = known,
		anchors = {},
		teleports = {},
		teleportReady = {},
		unknownFlightNotice = true,
	})
end

local function Has(plan, mode)
	for _, leg in ipairs(plan.legs) do
		if leg.mode == mode then
			return true
		end
	end
	return false
end

local STORMWIND, BOOTY_BAY = 2, 19
local entrance = assert(ns.Entrances[43], "Wailing Caverns has a door")
assert(entrance.name == "Wailing Caverns" and entrance.map == 1, "the door is on Kalimdor")
local from = { map = 0, x = -8800, y = 800, label = "Stormwind" }

-- No flight point is known: the run to Booty Bay's boat is the route, and the plan reports the unknown flight
-- point that would have shortened it.
local walked = assert(Plan(from, entrance, {}))
assert(not Has(walked, "flight"), "no known flight point means no flight")
assert(walked.unknownFlight == true, "the plan explains the flight point it could not use")
assert(walked.unknownFlightMaps and walked.unknownFlightMaps[0], "the faster flight is in the Eastern Kingdoms")
local first = walked.legs[1]
assert(
	first.mode == "walk" and first.to.kind == "dock" and first.yards > 5000,
	"with no flight point the whole way to the boat is walked"
)

-- Booty Bay's flight point is known, the reported case: the same journey first walks to Stormwind's flight
-- master (learning it) and flies to Booty Bay, so the long run to the boat is gone.
local booty = assert(Plan(from, entrance, { [BOOTY_BAY] = true }))
assert(booty.unknownFlight ~= true, "a route that flies needs no unknown-flight notice")
assert(not booty.unknownFlightMaps, "a route that flies names no continent")
assert(Has(booty, "flight"), "Booty Bay's known flight point is flown to")
assert(booty.legs[1].to.kind == "taxi" and booty.legs[1].to.id == STORMWIND, "the flight starts at Stormwind")
assert(booty.arrive < walked.arrive, "the known flight point beats the walked leg")

-- With Stormwind's flight point also known there is no walk to discover it at all, and the flight still wins.
local known = assert(Plan(from, entrance, { [STORMWIND] = true, [BOOTY_BAY] = true }))
assert(Has(known, "flight") and not known.legs[1].from.undiscovered, "both known nodes fly directly")
assert(known.arrive <= booty.arrive, "knowing the nearer flight point cannot make the journey slower")
assert(known.arrive < walked.arrive, "a known taxi node beats the walked leg")

local gromgol = { map = 0, x = -12414, y = 146, label = "Grom'gol" }
local lochModan = { map = 0, x = -5400, y = -2900, label = "Loch Modan" }
local hordeWalk = assert(Plan(gromgol, lochModan, {}, "Horde"))
assert(not Has(hordeWalk, "flight"), "with nothing known the Horde route to Loch Modan has no flight")
assert(
	hordeWalk.unknownFlightMaps and hordeWalk.unknownFlightMaps[0] and not hordeWalk.unknownFlightMaps[1],
	"a faster Eastern Kingdoms flight is reported, Kalimdor is not"
)
local stroll = assert(Plan(gromgol, { map = 0, x = -12300, y = 200, label = "Grom'gol" }, {}, "Horde"))
assert(not stroll.unknownFlightMaps, "a short walk no flight would beat reports no continent")

print("known taxi walk: a known flight point flies instead of walking: ok")
