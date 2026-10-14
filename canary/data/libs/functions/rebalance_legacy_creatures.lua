-- Pre/post-7.6 classification by creature NAME, never by sprite/race ID.
-- Baseline: Ezzz-dev/Nostalrius data/monster/monsters.xml (7.72 catalog).
-- Adjustments for cutoff: Morgaroth excluded (7.8); Cat/Human and renamed
-- Bonelord/Elder Bonelord/Hyena aliases included. Modern variants are separate.
-- https://github.com/Ezzz-dev/Nostalrius/blob/master/data/monster/monsters.xml
-- Per-definition override: introducedVersion = 7.6 (old) or >7.6 (modern).
-- Unlisted/custom definitions default to modern; audit/add old names here.
local names = {
    "raid orc", "raid orc warlord", "amazon", "ancient scarab", "apocalypse",
    "assassin", "badger", "bandit", "banshee", "bat", "bazir", "bear",
    "behemoth", "beholder", "bonelord", "black knight", "black sheep",
    "blue djinn", "bonebeast", "bug", "blue butterfly", "purple butterfly",
    "red butterfly", "yellow butterfly", "carniphila", "cat", "cave rat",
    "centipede", "chicken", "cobra", "crab", "crocodile", "crypt shambler",
    "cyclops", "dark monk", "deathslicer", "deer", "demodras", "demon",
    "demon skeleton", "dharalion", "dog", "dragon", "dragon lord", "dwarf",
    "dwarf geomancer", "dwarf guard", "dwarf soldier", "dworc fleshhunter",
    "dworc venomsniper", "dworc voodoomaster", "efreet", "elder beholder",
    "elder bonelord", "elephant", "elf", "elf arcanist", "elf scout",
    "the evil eye", "fernfang", "ferumbras", "fire devil", "fire elemental",
    "flamethrower", "flamingo", "frost troll", "gamemaster", "gargoyle",
    "gazer", "ghost", "ghoul", "giant spider", "goblin", "green djinn",
    "grorlam", "the halloween hare", "hero", "the horned fox", "human",
    "hunter", "hyaena", "hyena", "hydra", "illusion", "infernatil",
    "kongra", "larva", "lich", "lion", "lizard sentinel", "lizard snakecharmer",
    "lizard templar", "magicthrower", "marid", "merlkin", "mimic", "minotaur",
    "minotaur archer", "minotaur guard", "minotaur mage", "monk", "mummy",
    "general murius", "necromancer", "necropharus", "the old widow", "orc",
    "orc berserker", "orc leader", "orc rider", "orc shaman", "orc spearman",
    "orc warlord", "orc warrior", "orshabaal", "panda", "parrot", "ashmunrah",
    "dipthrah", "mahrdis", "morguthis", "omruc", "rahemos", "thalas",
    "vashresamun", "pig", "plaguethrower", "poison spider", "polar bear",
    "priestess", "rabbit", "rat", "rotworm", "scarab", "scorpion", "serpent spawn",
    "sheep", "shredderthrower", "sibang", "skeleton", "skunk", "slime", "slime2",
    "smuggler", "snake", "spider", "spit nettle", "stalker", "stone golem",
    "swamp troll", "tarantula", "terror bird", "tiger", "troll", "valkyrie",
    "vampire", "warlock", "war wolf", "wasp", "wild warrior", "winter wolf",
    "witch", "wolf", "yeti",
}
local result = {}
for _, name in ipairs(names) do result[name] = true end
return result