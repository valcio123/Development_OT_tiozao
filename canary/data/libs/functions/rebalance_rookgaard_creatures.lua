-- Species exemption applies worldwide, as requested. Exact names, not prefixes.
-- Rookgaard fauna, quests, accessible legacy zoo monsters and seasonal bosses.
-- Reference: https://www.tibiawiki.com.br/wiki/Categoria:Criaturas_de_Rookgaard
local names = {
    "bear", "bug", "cat", "cave rat", "chicken", "deer",
    "orc", "orc spearman", "pig", "poison spider", "rabbit", "rat",
    "seagull", "sheep", "snake", "spider", "wasp",
    "young troll", "island troll", "goblin", "goblin leader",
    "apprentice sheng", "diseased bill", "diseased dan",
    "diseased fred", "munster", "rookie", "the halloween hare",
    "cockroach", "silver rabbit", "blue butterfly", "red butterfly",
}
local excluded = {}
for _, name in ipairs(names) do excluded[name] = true end
return excluded
