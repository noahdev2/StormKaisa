--[[
    First Release By Storm Team (Raau,Martin) @ 13.Nov.2020    
]]

if Player.CharName ~= "Kaisa" then return end

require("common.log")
module("Storm Kai'sa", package.seeall, log.setup)

local clock = os.clock
local insert, sort = table.insert, table.sort
local huge, min, max, abs = math.huge, math.min, math.max, math.abs

local _SDK = _G.CoreEx
local Console, ObjManager, EventManager, Geometry, Input, Renderer, Enums, Game = _SDK.Console, _SDK.ObjectManager, _SDK.EventManager, _SDK.Geometry, _SDK.Input, _SDK.Renderer, _SDK.Enums, _SDK.Game
local Menu, Orbwalker, Collision, Prediction, HealthPred = _G.Libs.NewMenu, _G.Libs.Orbwalker, _G.Libs.CollisionLib, _G.Libs.Prediction, _G.Libs.HealthPred
local DmgLib, ImmobileLib, Spell = _G.Libs.DamageLib, _G.Libs.ImmobileLib, _G.Libs.Spell

---@type TargetSelector
local TS = _G.Libs.TargetSelector()
local Kaisa = {}

local spells = {
    Q = Spell.Active({
        Slot = Enums.SpellSlots.Q,
        Range = 600,
        Delay = 0.25
    }),
    W = Spell.Skillshot({
        Slot = Enums.SpellSlots.W,
        Range = 3000,
        Delay = 0.40,
        Speed = 1750,
        Radius = 200,
        Type = "Linear",
        Collisions = {WindWall=true,Minions=true,heroes=true},
        UseHitbox = true -- check
    }),
    E = Spell.Active({
        Slot = Enums.SpellSlots.E,
        Range = 475,
        Delay = 1.2,
    }),
    R = Spell.Targeted({
        Slot = Enums.SpellSlots.R,
        Delay = 0,
        Range = 1500
    }),
}

local function CountEnemiesInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "heroes")) do
        local hero = v.AsHero
        if hero and hero.IsTargetable and hero:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end
local function CountMinionsInRange(pos, range, t)
    local res = 0
    for k, v in pairs(t or ObjManager.Get("enemy", "minions")) do
        local minion = v.AsAI
        if minion and minion.IsTargetable and minion:Distance(pos) < range then
            res = res + 1
        end
    end
    return res
end
local function GameIsAvailable()
    return not (Game.IsChatOpen() or Game.IsMinimized() or Player.IsDead or Player.IsRecalling)
end

function Kaisa.GetRawDamageW()
   
    local wLevel = spells.W:GetLevel()
    return (30 + wLevel  * 25) + (1.3 * Player.TotalAD) + (0.7 * Player.TotalAP)
end

function Kaisa.IsEnabledAndReady(spell, mode)
    return Menu.Get(mode .. ".Use"..spell) and spells[spell]:IsReady()
end
local lastTick = 0
function Kaisa.OnTick()    
    if not GameIsAvailable() then return end 

    local gameTime = Game.GetTime()
    if gameTime < (lastTick + 0.25) then return end
    lastTick = gameTime    

    if Kaisa.Auto() then return end
    if not Orbwalker.CanCast() then return end

    local ModeToExecute = Kaisa[Orbwalker.GetMode()]
    if ModeToExecute then
        ModeToExecute()
    end
end
function Kaisa.OnDraw() 
    local playerPos = Player.Position
    local pRange = Orbwalker.GetTrueAutoAttackRange(Player)   
    

    for k, v in pairs(spells) do
        if Menu.Get("Drawing."..k..".Enabled", true) then
            Renderer.DrawCircle3D(playerPos, v.Range, 30, 2, Menu.Get("Drawing."..k..".Color")) 
        end
    end
end

function Kaisa.GetTargets(range)
    return {TS:GetTarget(range, true)}
end

function Kaisa.GetMinionsQ(t, team_lbl)
    for k, v in pairs(ObjManager.Get(team_lbl, "minions")) do
        local minion = v.AsAI
        local minionInRange = minion and minion.MaxHealth > 6 and spells.Q:IsInRange(minion)
        local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
        if minionInRange and not shouldIgnoreMinion and minion.IsTargetable then
            insert(t, minion)
        end                       
    
    end
end
function Kaisa.GetMinionsW(t, team_lbl)
    for k, v in pairs(ObjManager.Get(team_lbl, "minions")) do
        local minion = v.AsAI
        local minionInRange = minion and minion.MaxHealth > 6 and spells.W:IsInRange(minion)
        local shouldIgnoreMinion = minion and (Orbwalker.IsLasthitMinion(minion) or Orbwalker.IsIgnoringMinion(minion))
        if minionInRange and not shouldIgnoreMinion and minion.IsTargetable then
            insert(t, minion)
        end                       
    
    end
end
function Kaisa.ComboLogic(mode)
    if Kaisa.IsEnabledAndReady("W", mode) then
        local wChance = Menu.Get(mode .. ".ChanceW")
        for k, wTarget in ipairs(Kaisa.GetTargets(spells.W.Range)) do
            if spells.W:CastOnHitChance(wTarget, wChance) then
                return
            end
        end
    end
    if Kaisa.IsEnabledAndReady("Q", mode) then
        for k, qTarget in ipairs(Kaisa.GetTargets(spells.Q.Range)) do
           local count = CountEnemiesInRange(Player.Position,spells.Q.Range)
            if count < 3 then
                spells.Q:Cast()
                return
            end
        end
    end    
    if Kaisa.IsEnabledAndReady("E", mode) then
        for k, eTarget in ipairs(Kaisa.GetTargets(spells.E.Range)) do
            if spells.E:Cast() then
                return
            end
        end
    end    
end
function Kaisa.HarassLogic(mode)
    local PM = Player.Mana / Player.MaxMana * 100
    local SettedMana = Menu.Get("Harass.Mana")
    if SettedMana > PM then 
        return 
        end
    if Kaisa.IsEnabledAndReady("W", mode) then
        local wChance = Menu.Get(mode .. ".ChanceW")
        for k, wTarget in ipairs(Kaisa.GetTargets(spells.W.Range)) do
            if spells.W:CastOnHitChance(wTarget, wChance) then
                return
            end
        end
    end
    if Kaisa.IsEnabledAndReady("Q", mode) then
        for k, qTarget in ipairs(Kaisa.GetTargets(spells.Q.Range)) do
           local count = CountEnemiesInRange(Player.Position,spells.Q.Range)
            if count < 3 then
                spells.Q:Cast()
                return
            end
        end
    end    
    if Kaisa.IsEnabledAndReady("E", mode) then
        for k, eTarget in ipairs(Kaisa.GetTargets(spells.E.Range)) do
            if spells.E:Cast() then
                return
            end
        end
    end    
end

function Kaisa.FarmLogic(minions)    
    local jungleW = Menu.Get("Clear.JungleW")
    for k, minion in ipairs(minions) do
        if minion.IsMonster 
        then 
           if spells.W:IsReady() and jungleW then spells.W:CastOnHitChance(minion,Enums.HitChance.Low)  end
            if spells.Q:IsReady() then spells.Q:Cast() end
            return true
        end                       
    end    
    local Count = Menu.Get("Clear.count")
    if CountMinionsInRange(Player.Position,spells.Q.Range) > Count then 
        spells.Q:Cast()
    end
end

function Kaisa.Auto() 
    if not spells.W:IsReady() then return end

    local pPos = Player.Position
    local rawDmg = Kaisa.GetRawDamageW()
    local KSW = Menu.Get("KillSteal.W")
    
    local points = {}
    for k, wTarget in ipairs(TS:GetTargets(spells.W.Range, true)) do        
        local pred = spells.W:GetPrediction(wTarget)
        if pred and pred.HitChanceEnum >= Enums.HitChance.VeryHigh then
            insert(points, pred.CastPosition)

            if KSW  then
                local WDMG = DmgLib.CalculateMagicalDamage(Player, wTarget, rawDmg)
                local ksHealth = spells.W:GetKillstealHealth(wTarget)
                
                if WDMG > ksHealth and spells.W:Cast(pred.CastPosition) then
                    return
                end 
            end
        end   
    end

end

function Kaisa.Combo()  Kaisa.ComboLogic("Combo")  end
function Kaisa.Harass() Kaisa.HarassLogic("Harass") end
function Kaisa.Waveclear()
    local pPos = Player.Position
    


    local farmQ   = Menu.Get("Clear.FarmQ")
    local jungleQ = Menu.Get("Clear.JungleQ")
    if not (farmQ or jungleQ ) then return end

    local minionsInRange = {}
    do -- Fill Minions In Range And Sort
        if jungleQ then Kaisa.GetMinionsQ(minionsInRange, "neutral") end
        if farmQ  then Kaisa.GetMinionsQ(minionsInRange, "enemy") end        
        sort(minionsInRange, function(a, b) return a.MaxHealth > b.MaxHealth end)
    end    

    if farmQ and Kaisa.FarmLogic(minionsInRange) then 
        return
    end 
end



function Kaisa.LoadMenu()

    Menu.RegisterMenu("StormKaisa", "Storm Kaisa", function()
        Menu.ColumnLayout("cols", "cols", 2, true, function()
            Menu.ColoredText("Combo", 0xFFD700FF, true)
            Menu.Checkbox("Combo.UseQ",   "Use [Q]", true) 
            Menu.Checkbox("Combo.UseW",   "Use [W]", true)
            Menu.Slider("Combo.ChanceW", "HitChance [W]", 0.7, 0, 1, 0.05)
            Menu.Checkbox("Combo.UseE",   "Use [E]", true)     

            Menu.NextColumn()

            Menu.ColoredText("Harass", 0xFFD700FF, true)
            Menu.Slider("Harass.Mana", "Mana Percent ", 50,0, 100)
            Menu.Checkbox("Harass.UseQ",   "Use [Q]", true)   
            Menu.Checkbox("Harass.UseW",   "Use [W]", true)
            Menu.Slider("Harass.ChanceW", "HitChance [W]", 0.85, 0, 1, 0.05)
            Menu.Checkbox("Harass.UseE",   "Use [E]", false)    
        end)
        Menu.Separator()

        Menu.ColoredText("Clear", 0xFFD700FF, true)
        Menu.Checkbox("Clear.FarmQ",   "Use [Q] Farm", true)
        Menu.Slider("Clear.count", "Clear if X >", 3,1,5)  
        Menu.Checkbox("Clear.JungleQ", "Use [Q] Jungle", true)
        Menu.Checkbox("Clear.JungleW", "Use [W] Jungle", true)
          
        Menu.Separator()

        Menu.ColoredText("KillSteal Options", 0xFFD700FF, true)
        Menu.Checkbox("KillSteal.W", "Use [W] to KS", true)      
        Menu.Separator()

        Menu.ColoredText("Draw Options", 0xFFD700FF, true)
        Menu.Checkbox("Drawing.Q.Enabled",   "Draw [Q] Range")
        Menu.ColorPicker("Drawing.Q.Color", "Draw [Q] Color", 0xEF476FFF) 
        Menu.Checkbox("Drawing.W.Enabled",   "Draw [W] Range")
        Menu.ColorPicker("Drawing.W.Color", "Draw [W] Color", 0x06D6A0FF) 
        Menu.Checkbox("Drawing.E.Enabled",   "Draw [E] Range")
        Menu.ColorPicker("Drawing.E.Color", "Draw [E] Color", 0x118AB2FF)     
    end)     
end

function OnLoad()
    Kaisa.LoadMenu()
    for eventName, eventId in pairs(Enums.Events) do
        if Kaisa[eventName] then
            EventManager.RegisterCallback(eventId, Kaisa[eventName])
        end
    end    
    return true
end