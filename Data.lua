local _, SR = ...

-- Category definitions for grouping factions
SR.CATEGORIES = {
    { key = "dungeon",   en = "Dungeon Factions",   kr = "던전 진영" },
    { key = "shattrath", en = "Shattrath City",      kr = "샤트라스" },
    { key = "raid",      en = "Raid Factions",       kr = "레이드 진영" },
}

-- Reputation faction IDs and dungeon mappings for TBC
SR.FACTIONS = {
    -- Dungeon factions
    {
        id = 946,
        name_en = "Honor Hold",
        category = "dungeon",
        zone = { en = "Hellfire Peninsula", kr = "지옥불 반도" },
        alliance = true,
        dungeons = {
            { en = "Hellfire Ramparts",   kr = "지옥불 성루" },
            { en = "The Blood Furnace",   kr = "피의 용광로" },
            { en = "The Shattered Halls", kr = "으스러진 손의 전당" },
        },
    },
    {
        id = 947,
        name_en = "Thrallmar",
        category = "dungeon",
        zone = { en = "Hellfire Peninsula", kr = "지옥불 반도" },
        horde = true,
        dungeons = {
            { en = "Hellfire Ramparts",   kr = "지옥불 성루" },
            { en = "The Blood Furnace",   kr = "피의 용광로" },
            { en = "The Shattered Halls", kr = "으스러진 손의 전당" },
        },
    },
    {
        id = 942,
        name_en = "Cenarion Expedition",
        category = "dungeon",
        zone = { en = "Zangarmarsh", kr = "장가르 습지대" },
        dungeons = {
            { en = "The Slave Pens",  kr = "강제노역소" },
            { en = "The Underbog",    kr = "지하수렁" },
            { en = "The Steamvault",  kr = "증기 저장고" },
        },
    },
    {
        id = 1011,
        name_en = "Lower City",
        category = "dungeon",
        zone = { en = "Auchindoun", kr = "아키나이" },
        dungeons = {
            { en = "Mana-Tombs",        kr = "마나 무덤" },
            { en = "Auchenai Crypts",   kr = "아키나이 납골당" },
            { en = "Sethekk Halls",     kr = "세데크 전당" },
            { en = "Shadow Labyrinth",  kr = "그림자 미궁" },
        },
    },
    {
        id = 935,
        name_en = "The Sha'tar",
        category = "dungeon",
        zone = { en = "Tempest Keep", kr = "폭풍우 요새" },
        dungeons = {
            { en = "The Mechanar",  kr = "메카나르" },
            { en = "The Botanica",  kr = "식물원" },
        },
    },
    {
        id = 989,
        name_en = "Keepers of Time",
        category = "dungeon",
        zone = { en = "Caverns of Time", kr = "시간의 동굴" },
        dungeons = {
            { en = "Old Hillsbrad Foothills", kr = "옛 힐스브래드 구릉지" },
            { en = "The Black Morass",        kr = "검은늪" },
        },
    },
    -- Shattrath factions
    {
        id = 932,
        name_en = "The Aldor",
        category = "shattrath",
        zone = { en = "Shattrath City", kr = "샤트라스" },
        dungeons = {},
        items = {
            { en = "Mark of Kil'jaeden",  kr = "킬제덴의 징표",   note_en = "Neutral \226\134\146 Honored",  note_kr = "중립 \226\134\146 존경",
              desc_en = "Outland demons (lv60-), 10 per turn-in", desc_kr = "아웃랜드 악마 (60레벨 이하) 드랍, 10개 단위 반납" },
            { en = "Mark of Sargeras",    kr = "살게라스의 징표",  note_en = "Honored \226\134\146 Exalted",  note_kr = "존경 \226\134\146 확고한 동맹",
              desc_en = "Outland demons (lv66+), 25 rep each, 1 or 10 per turn-in", desc_kr = "아웃랜드 악마 (66레벨+) 드랍, 개당 25 평판, 1개 또는 10개 반납" },
            { en = "Fel Armament",        kr = "지옥의 무기",     note_en = "All levels",            note_kr = "전 등급",
              desc_en = "Rare drop from Outland demons, 350 rep, rewards Holy Dust", desc_kr = "아웃랜드 악마 희귀 드랍, 350 평판, 신성한 가루 보상" },
        },
    },
    {
        id = 934,
        name_en = "The Scryers",
        category = "shattrath",
        zone = { en = "Shattrath City", kr = "샤트라스" },
        dungeons = {},
        items = {
            { en = "Firewing Signet",  kr = "화날개 인장",  note_en = "Neutral \226\134\146 Honored",  note_kr = "중립 \226\134\146 존경",
              desc_en = "Firewing blood elves in Terokkar, 10 per turn-in", desc_kr = "테로카르 화날개 블러드엘프 드랍, 10개 단위 반납" },
            { en = "Sunfury Signet",   kr = "선퓨리 인장",  note_en = "Honored \226\134\146 Exalted",  note_kr = "존경 \226\134\146 확고한 동맹",
              desc_en = "Sunfury blood elves (lv66+), 25 rep each, 1 or 10 per turn-in", desc_kr = "선퓨리 블러드엘프 (66레벨+) 드랍, 개당 25 평판, 1개 또는 10개 반납" },
            { en = "Arcane Tome",      kr = "비전 고서",    note_en = "All levels",            note_kr = "전 등급",
              desc_en = "Rare drop from blood elves, 350 rep, rewards Arcane Rune", desc_kr = "블러드엘프 희귀 드랍, 350 평판, 비전의 룬 보상" },
        },
    },
    -- Raid factions
    {
        id = 1012,
        name_en = "Ashtongue Deathsworn",
        category = "raid",
        zone = { en = "Shadowmoon Valley", kr = "어둠달 골짜기" },
        dungeons = {
            { en = "Black Temple", kr = "검은 사원", raid = true },
        },
    },
    {
        id = 990,
        name_en = "The Scale of the Sands",
        category = "raid",
        zone = { en = "Caverns of Time", kr = "시간의 동굴" },
        dungeons = {
            { en = "Hyjal Summit", kr = "하이잘 산 전투", raid = true },
        },
    },
    {
        id = 967,
        name_en = "The Violet Eye",
        category = "raid",
        zone = { en = "Deadwind Pass", kr = "저승바람 고개" },
        dungeons = {
            { en = "Karazhan", kr = "카라잔", raid = true },
        },
    },
}

-- Standing colors (better differentiation than FACTION_BAR_COLORS)
SR.STANDING_COLORS = {
    [1] = { r = 0.8,  g = 0.13, b = 0.13 }, -- Hated (red)
    [2] = { r = 0.8,  g = 0.26, b = 0.13 }, -- Hostile (orange-red)
    [3] = { r = 0.75, g = 0.47, b = 0.07 }, -- Unfriendly (orange)
    [4] = { r = 0.9,  g = 0.7,  b = 0.0 },  -- Neutral (yellow)
    [5] = { r = 0.0,  g = 0.7,  b = 0.0 },  -- Friendly (green)
    [6] = { r = 0.0,  g = 0.6,  b = 0.1 },  -- Honored (dark green)
    [7] = { r = 0.0,  g = 0.5,  b = 0.9 },  -- Revered (blue)
    [8] = { r = 0.0,  g = 0.9,  b = 0.7 },  -- Exalted (cyan)
}
