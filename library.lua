-- Make this a singleton
-- eg, there will only ever be one copy
if ... ~= "library" then
  return require("library")
end
local util = require("util")

---@diagnostic disable-next-line: access-invisible
---@class PennyismsGlobals
local PM_Global = _ENV.__PM or {}
_ENV.__PM = PM_Global

---@alias product_type "fluid"|"item"
---@alias product_amount data.FluidAmount|uint16

---@class Pennyisms
local PM = {}

--MARK: Inner Library

---@generic T
---@param list T[]
---@param filter fun(a:T):boolean
function PM.remove_from_list(list, filter)
  local bad_indexes, bad_count = {}, 0
  for index, ingredient in pairs(list) do
    if filter(ingredient) then
      bad_count = bad_count + 1
      bad_indexes[bad_count] = index
    end
  end

  for i = bad_count, 1, -1 do
    table.remove(list, bad_indexes[i])
  end
end

---@generic T : string
---@param array T[]
---@return table<T,true>
function PM.array_to_lookup(array)
  local lookup = {}
  for _, item in pairs(array) do
    lookup[item] = true
  end
  return lookup
end

---@generic T
---@param array T[]
---@param value T
---@return boolean
function PM.array_contains(array, value)
  for _, item in pairs(array) do
    if item == value then return true end
  end
  return false
end

---MARK: Type validation

---@param x number
---@param min number
---@param max number
local function float_range(x, min, max)
  if x < min then return false end
  if x > max then return false end
  return true
end

---@param x number
---@param min int
---@param max int
---@return TypeGuard<int>
local function int_range(x, min, max)
  local _, fraction = math.modf(x)
  if fraction ~= 0 then return false end
  if not float_range(x, min, max) then return false end
  return true
end

PM.validate = {
  ---@return TypeGuard<int8>
  int8 = function(x) return int_range(x, -2^7, 2^7-1) end,
  ---@return TypeGuard<int16>
  int16 = function(x) return int_range(x, -2^15, 2^15-1) end,
  ---@return TypeGuard<int32>
  int32 = function(x) return int_range(x, -2^31, 2^31-1) end,
  ---@return TypeGuard<uint8>
  uint8 = function(x) return int_range(x, 0, 2^8-1) end,
  ---@return TypeGuard<uint16>
  uint16 = function(x) return int_range(x, 0, 2^16-1) end,
  ---@return TypeGuard<uint32>
  uint32 = function(x) return int_range(x, 0, 2^32-1) end,
  ---@return TypeGuard<uint64>
  uint64 = function(x) return int_range(x, 0, 2^53) end,
  ---@return TypeGuard<float|double>
  number = function(x) return x == x end,
  ---@return TypeGuard<integer>
  integer = function(x)
    local _, fraction = math.modf(x)
    return fraction == 0
  end,
  ---@return TypeGuard<data.FluidAmount|FluidAmount>
  fluidamount = function(x) return float_range(x, 0, 2^40-(1/2^24)) end,

  float_range = float_range,
  int_range = int_range,
}

--MARK: Flag Functions

---Returns whether or not the given flaglist contains the given flag
---@param flagged_obj {flags:string[]?}
---@param flag string
---@return boolean
---@overload fun(flagged_obj:data.SpritePrototype, flag:data.SpriteFlags):boolean
---@overload fun(flagged_obj:data.SpriteParameters, flag:data.SpriteFlags):boolean
---@overload fun(flagged_obj:data.AnimationPrototype, flag:data.SpriteFlags):boolean
---@overload fun(flagged_obj:data.ItemPrototype, flag:data.ItemPrototypeFlags):boolean
---@overload fun(flagged_obj:data.EntityPrototype, flag:data.EntityPrototypeFlags):boolean
---@overload fun(flagged_obj:data.RailSignalPrototype, flag:data.EntityPrototypeFlags):boolean
---@overload fun(flagged_obj:data.TransportBeltConnectablePrototype, flag:data.EntityPrototypeFlags):boolean
function PM.has_flag(flagged_obj, flag)
  -- Does not have the flag if there's no flags
  if not flagged_obj.flags then return false end
  
  return PM.array_contains(flagged_obj.flags, flag)
end
---Adds the flag if it wasn't already in the list.
---@param flagged_obj {flags:string[]?}
---@param flag string
---@overload fun(flagged_obj:data.SpritePrototype, flag:data.SpriteFlags)
---@overload fun(flagged_obj:data.SpriteParameters, flag:data.SpriteFlags)
---@overload fun(flagged_obj:data.AnimationPrototype, flag:data.SpriteFlags)
---@overload fun(flagged_obj:data.ItemPrototype, flag:data.ItemPrototypeFlags)
---@overload fun(flagged_obj:data.EntityPrototype, flag:data.EntityPrototypeFlags)
---@overload fun(flagged_obj:data.RailSignalPrototype, flag:data.EntityPrototypeFlags)
---@overload fun(flagged_obj:data.TransportBeltConnectablePrototype, flag:data.EntityPrototypeFlags)
function PM.set_flag(flagged_obj, flag)
  if not flagged_obj.flags then
    flagged_obj.flags = {flag}
  else
    if not PM.has_flag(flagged_obj, flag) then
      table.insert(flagged_obj.flags, flag)
    end
  end
end
---Removes every instance of the given flag in the flaglist. Flags should only exist once, but who knows what other mods are doing.
---@param flagged_obj {flags:string[]?}
---@param flag string
---@overload fun(flagged_obj:data.SpritePrototype, flag:data.SpriteFlags)
---@overload fun(flagged_obj:data.SpriteParameters, flag:data.SpriteFlags)
---@overload fun(flagged_obj:data.AnimationPrototype, flag:data.SpriteFlags)
---@overload fun(flagged_obj:data.ItemPrototype, flag:data.ItemPrototypeFlags)
---@overload fun(flagged_obj:data.EntityPrototype, flag:data.EntityPrototypeFlags)
---@overload fun(flagged_obj:data.RailSignalPrototype, flag:data.EntityPrototypeFlags)
---@overload fun(flagged_obj:data.TransportBeltConnectablePrototype, flag:data.EntityPrototypeFlags)
function PM.remove_flag(flagged_obj, flag)
  local flaglist = flagged_obj.flags
  -- Don't do anything if there's no flaglist
  if not flaglist then return end

  ---@type uint[]
  local flag_index = {}
  -- Collect the indexes of the flag we're removing
  for index, listed_flag in pairs(flaglist) do
    if listed_flag == flag then table.insert(flag_index, index) end
  end

  -- Walk backwards to remove the flags.
  -- We'll be shifting the index of the flags ahead of us otherwise.
  for i = #flag_index, 1, -1 do
    table.remove(flaglist, flag_index[i])
  end
end

--MARK: Recipe Ingredients

---Quickly makes the IngredientPrototype as if by using shorthand
---@param name data.ItemID|data.FluidID
---@param amount product_amount
---@param type product_type?
---@param index uint32?
---@overload fun(name:data.ItemID,amount:number,type:"item"|nil):data.ItemIngredientPrototype
---@overload fun(name:data.FluidID,amount:number,type:"fluid",index:uint32):data.FluidIngredientPrototype
---@return data.IngredientPrototype
function PM.ingredient(name, amount, type, index)
  return {
    name = name,
    amount = amount,
    type = type or "item",
    fluidbox_index = index
  }--[[@as data.IngredientPrototype]]
end
---Shorthand for an catalyst ingredient
---@param name data.ItemID|data.FluidID
---@param amount product_amount
---@param catalyst product_amount?
---@param type product_type?
---@param index uint32?
---@return data.IngredientPrototype
---@overload fun(name:data.ItemID,amount:number,catalyst:number,type:"item"|nil):data.ItemIngredientPrototype
---@overload fun(name:data.FluidID,amount:number,catalyst:number,type:"fluid",index:uint32):data.FluidIngredientPrototype
function PM.catalyst_ingredient(name, amount, catalyst, type, index)
  return {
    name = name,
    amount = amount,
    ignored_by_stats = catalyst or amount,
    type = type or "item",
    fluidbox_index = index
  }--[[@as data.IngredientPrototype]]
end

--MARK: Recipe Products

---@param min uint16
---@param max? uint16
---@param level? int
local function validate_item_amounts(min, max, level)
  level = level and level + 1 or 2
  if not max then
    if not PM.validate.uint16(min) then
      error("Product result must be a uint16", level)
    end
  else
    if not PM.validate.uint16(min) then
      error("Product minimum result must be a uint16", level)
    elseif not PM.validate.uint16(min) then
      error("Product maximum result must be a uint16", level)
    elseif not float_range(max, min, 1/0) then
      error("Product maximum must be >= minimum", level)
    end
  end
end

---@param min data.FluidAmount
---@param max? data.FluidAmount
---@param level? int
local function validate_fluid_amounts(min, max, level)
  level = level and level + 1 or 2
  if not max then
    if not PM.validate.fluidamount(min) then
      error("Product result cannot be valid FluidAmount", level)
    end
  else
    if not PM.validate.fluidamount(min) then
      error("Product minimum result must be a valid FluidAmount", level)
    elseif not PM.validate.fluidamount(max) then
      error("Product maximum result must be a valid FluidAmount")
    elseif not float_range(max, min, 1/0) then
      error("Product maximum must be >= minimum", level)
    end
  end
end

---@param type product_type?
---@param min uint16|data.FluidAmount
---@param max? uint16|data.FluidAmount
---@param level? int
---@overload fun(amount:number)
local function validate_amounts(type, min, max, level)
  level = level and level + 1 or 2
  if type == "fluid" then
    ---@cast min data.FluidAmount
    ---@cast max data.FluidAmount?
    return validate_fluid_amounts(min, max, level)
  else
    ---@cast min uint16
    ---@cast max uint16?
    return validate_item_amounts(min, max, level)
  end
end

---@param min number?
---@param max? number
---@param level? int
---@return data.SharedProbabilityDefinition?
---@overload fun(amount:number?)
---@overload fun(min:number,max:number):data.SharedProbabilityDefinition
local function validate_chance(min, max, level)
  level = level and level + 1 or 2
  if not min then return end
  if not max then
    if not float_range(min, 0, 1) then
      error("Product probability must be within [0-1]", level)
    end
  else
    if not float_range(min, 0, max) then
      error("Shared probability minimum must be within [0-max]", level)
    elseif not float_range(max, min, 1) then
      error("Shared probability maximum must be within [min-1]", level)
    end
    return {
      min = min,
      max = max,
    }
  end
end

--MARK: Product Builder

---@alias Pick<T, K extends keyof T> {[P in K]: T[P];}
---@alias Omit<T, K extends keyof T> Pick<T, Exclude<keyof T, K>>
---@alias PartialExcept<T, K extends keyof T> Pick<T,K> & Partial<Omit<T,K>>

---@alias product_builder product_builder.item | product_builder.fluid

---@alias product_builder.base.partial
---   PartialExcept<product_builder.base,'prod'|'done'>
---@class product_builder.base
---@field prod data.ProductPrototype
local product_builder_base = {}

---@alias product_builder.fluid.partial
---   PartialExcept<product_builder.fluid,'prod'|'done'>
---@class (partial) product_builder.fluid : product_builder.base
---@field prod data.FluidProductPrototype
local product_builder_fluid

---@alias product_builder.item.partial
---   PartialExcept<product_builder.item,'prod'|'done'>
---@class (partial) product_builder.item :product_builder.base
---@field prod data.ItemProductPrototype
local product_builder_item


-- -@param name data.ItemID|data.FluidID
-- -@param type? product_type
-- -@return product_builder
---@overload fun(name:data.ItemID):product_builder.item
---@overload fun(name:data.FluidID,type:"fluid"):product_builder.fluid
function PM.product(name, type, bandaid)
  local self
  if type == "fluid" then
    self = util.copy(product_builder_fluid)
  else
    self = util.copy(product_builder_item)
  end
  self.prod = {
    name = name,
    type = type or "item"
  }
  return self
end

---MARK: Base Functions

---@generic T : product_builder.base.partial
---@param self T
---@return data.ProductPrototype
-- -@overload fun(self:product_builder.item.partial):data.ItemProductPrototype
-- -@overload fun(self:product_builder.fluid.partial):data.FluidProductPrototype
function product_builder_base.done(self)
  if self.amount then
    error("Product needs to have an amount set before it can be finished")
  end
  return self.prod
end

---@generic T : product_builder.base.partial
---@param self T
---@param min product_amount
---@param max? product_amount
---@return Omit<T,'amount'>
---@overload fun(self:T,amount:product_amount):Omit<T,'amount'>
function product_builder_base.amount(self, min, max)
  self.amount = nil
  local prod = self.prod

  validate_amounts(prod.type, min, max)
  if max then
    prod.amount_min = min
    prod.amount_max = max
  else
    prod.amount = min
  end

  return self
end

---@param product data.ProductPrototype
---@param error_message any
---@return product_amount min
---@return product_amount max
---@overload fun(product:data.ItemProductPrototype,error_message:any):uint16,uint16
---@overload fun(product:data.FluidProductPrototype,error_message:any):data.FluidAmount,data.FluidAmount
local function get_amount(product, error_message)
  if product.amount then
    return product.amount, product.amount
  else
    if not product.amount_min or not product.amount_max then
      error(error_message, 2)
    end
    return product.amount_min, product.amount_max
  end
end

---@generic T : product_builder.base.partial
---@param self T
---@param num? product_amount
---@return Omit<T,'catalyst'|'static_quality'>
---@overload fun<T:product_builder.item.partial>(self:T,num?:product_amount,can_quality:true):Omit<T,'catalyst'|'static_quality'>
function product_builder_base.catalyst(self,num, can_quality)
  self.catalyst = nil
  self--[[@as product_builder.item.partial]].static_quality = nil
  local product = self.prod
  local min,max = get_amount(product, "Product amount must be defined before Catalyst amount")
  num = num or max

  if product.type == "item" then
    if not PM.validate.uint16(num) then
      error("Catalyst amount must be a uint16")
    end
  else
    if not PM.validate.fluidamount(num) then
      error("Catalyst amount must be a valid FluidAmount")
    end
  end

  product.ignored_by_productivity = num
  product.ignored_by_stats = num

  if not can_quality then
    product.affected_by_quality = false
  end

  return self
end

---@generic T : product_builder.base.partial
---@param self T
---@param num? product_amount
---@return Omit<T,'catalyst'|'ignored'>
function product_builder_base.ignored(self, num)
  self.catalyst = nil
  self.ignored = nil
  local product = self.prod
  local min,max = get_amount(product, "Product amount must be defined before Ignored amount")
  num = num or max

  if num == product.ignored_by_stats then
    error("Unecessary call to set ignored amount to the same as catalyst amount")
  end
  if product.type == "item" then
    if not PM.validate.uint16(num) then
      error("Ignored amount must be a uint16")
    end
  else
    if not PM.validate.fluidamount(num) then
      error("ignored amount must be a valid FluidAmount")
    end
  end
  product.ignored_by_stats = num

  return self
end

---@generic T : product_builder.base.partial
---@param self T
---@param min number
---@param max? number
---@return Omit<T,'chance'|'combined_chance'>
---@overload fun(self:T,chance:number):Omit<T,'chance'|'combined_chance'>
function product_builder_base.chance(self,min,max)
  self.chance = nil
  self.combined_chance = nil
  local shared = validate_chance(min, max)
  if shared then
    self.prod.shared_probability = shared
  else
    self.prod.independent_probability = min
  end
  return self
end

---@generic T : product_builder.base.partial
---@param self T
---@param prob number
---@param min number
---@param max number
---@return Omit<T,'chance'|'combined_chance'>
function product_builder_base.combined_chance(self,prob,min,max)
  self.chance = nil
  self.combined_chance = nil
  validate_chance(min)
  self.prod.shared_probability = validate_chance(min, max)
  self.prod.independent_probability = min
  return self
end

--MARK: Fluid Functions

---@class (partial) product_builder.fluid
product_builder_fluid = util.copy(product_builder_base)

---@generic T : product_builder.fluid.partial
---@param self T
---@param index uint32
---@param ... uint32 optional_indexes
---@return Omit<T,'index'>
function product_builder_fluid.index(self,index, ...)
  self.index = nil

  if not PM.validate.uint32(index) then
    error("Fluidbox index must be a uint32")
  elseif index == 0 then
    error("Fluidbox index is already 0 by default. There is no point of defining it as so")
  end

  local additional = {...}
  ---@type {[uint32]?:true}
  local seen_indexes = {[index]=true}
  for i, index in pairs(additional) do
    if not PM.validate.uint32(index) or index == 0 then
      error("Optional fluidbox index ["..i.."] must be a non-zero uint32")
    elseif seen_indexes[index] then
      error("Fluidbox indexes must be unique within a recipe")
    end
    seen_indexes[index] = true
  end

  if not next(additional) then
    ---@diagnostic disable-next-line: assign-type-mismatch
    additional = nil
  end

  self.prod.fluidbox_index = index
  self.prod.optional_fluidbox_indexes = additional
  
  ---@diagnostic disable-next-line: return-type-mismatch
  return self
end

---@generic T : product_builder.fluid.partial
---@param self T
---@param temperature number
---@return Omit<T,'temperature'>
function product_builder_fluid.temperature(self, temperature)
  self.temperature = nil
  if not PM.validate.number(temperature) then
    error("Temperature must not be NaN")
  end
  self.prod.temperature = temperature
  return self
end

---@generic T : product_builder.fluid.partial
---@param self T
---@param multiplier uint8
---@return Omit<T,'multiplier'>
function product_builder_fluid.buffer(self, multiplier)
  self.buffer = nil
  if not PM.validate.uint8(multiplier) or multiplier == 0 then
    error("Fluidbox multiplier must be a non-zero uint8")
  end
  self.prod.fluidbox_multiplier = multiplier
  return self
end

--MARK: Item Functions

---@class (partial) product_builder.item
product_builder_item = util.copy(product_builder_base)

---@generic T extends product_builder.item.partial
---@param self T
---@param fraction number
---@return Omit<T,'extra'>
function product_builder_item.extra(self, fraction)
  self.extra = nil
  if not float_range(fraction, 0, 1) or fraction == 1 then
    error("Extra count fraction has to be a float within [0-1)")
  end
  self.prod.extra_count_fraction = fraction
  return self
end

---@generic T extends product_builder.item.partial
---@param self T
---@param reset boolean If product doesn't spoil while crafting, it will reset to perfectly fresh.
---@param fresh boolean Causes the product to start the craft as fresh as `percent_spoiled` allows it to be
---@return Omit<T,'fresh'>
function product_builder_item.fresh(self,reset, fresh)
  self.fresh = nil
  if not reset and not fresh then
    error("Unecessary call to fresh to mark items as not fresh (default)")
  end
  self.prod.reset_freshness_on_craft = reset
  self.prod.always_fresh = reset
  return self
end

--- Give bounds to clamp to after quality_change and then the quality roll
---@generic T extends product_builder.item.partial
---@param self T
---@param min? data.QualityID
---@param max? data.QualityID
---@return Omit<T,'quality_range'>
function product_builder_item.quality_range(self, min, max)
  self.quality_range = nil
  -- FIXME: Do I want to actually check if the QualityID's are valid?
  self.prod.quality_min = min
  self.prod.quality_max = min
  return self
end

---@generic T extends product_builder.item.partial
---@param self T
---@param bump uint8
---@return Omit<T,'quality_bump'>
function product_builder_item.quality_bump(self, bump)
  self.quality_bump = nil
  if not PM.validate.int8(bump) then
    error("Quality change must be an int8")
  elseif bump == 0 then
    error("Defining a quality change of 0 is unecessary")
  end
  self.prod.quality_change = bump
  return self
end

---@generic T extends product_builder.item.partial
---@param self T
---@return Omit<T,'static_quality'>
function product_builder_item.static_quality(self)
  self.static_quality = nil
  self.prod.affected_by_quality = false
  return self
end

--MARK: Recipe Manipulation

---@param item data.ItemID|data.FluidID
---@param type product_type?
---@return fun(a:data.IngredientPrototype|data.ProductPrototype):boolean
local function ingredient_product_matches(item, type)
  type = type or "item"
  return function (ingredient)
    return ingredient.type == type and ingredient.name == item
  end
end
---@param ingredients data.IngredientPrototype[]
---@param item data.ItemID|data.FluidID
---@param type product_type?
function PM.remove_ingredient(ingredients, item, type)
  PM.remove_from_list(ingredients, ingredient_product_matches(item, type))
end
---@param products data.ProductPrototype[]
---@param item data.ItemID|data.FluidID
---@param type product_type?
function PM.remove_products(products, item, type)
  PM.remove_from_list(products, ingredient_product_matches(item, type))
end

-- MARK: Entity Functions

---A shorthand for the LootItem
---@param item data.ItemID
---@param count_min uint16? Default is `1`
---@param count_max uint16? must be `> 0`, Default is `1`
---@param probability number? must be between `0` and `1`, Default is `1`
---@return data.ItemProductPrototype
function PM.loot(item, count_min, count_max, probability)
  if probability then
    return PM.product(item)
      :amount(count_min or 1, count_max)
      :chance(probability)
      :done()--[[@as data.ItemProductPrototype]]
  else
    return PM.product(item)
      :amount(count_min or 1, count_max)
      :done()--[[@as data.ItemProductPrototype]]
  end
end

-- MARK: Technology Functions

---Shorthand for the effect of unlocking a recipe
---@param recipe data.RecipeID
---@param hidden? boolean
---@return data.UnlockRecipeModifier
function PM.unlock_recipe(recipe, hidden)
  return {
    type = "unlock-recipe",
    recipe = recipe,
    hidden = hidden,
  }--[[@as data.UnlockRecipeModifier]]
end
---Shorthand for the effect of unlocking a space location (aka planet)
---@param location data.SpaceLocationID
---@param hidden? boolean
---@return data.UnlockSpaceLocationModifier
function PM.unlock_location(location, hidden)
  return {
    type = "unlock-space-location",
    space_location = location,
    hidden = hidden,
  }--[[@as data.UnlockSpaceLocationModifier]]
end
---Shorthand for the effect of unlocking a quality level
---@param quality data.QualityID
---@param hidden? boolean
---@return data.UnlockQualityModifier
function PM.unlock_quality(quality, hidden)
  return {
    type = "unlock-quality",
    quality = quality,
    hidden = hidden,
  }--[[@as data.UnlockQualityModifier]]
end
---Shorthand for giving an item
---@param item data.ItemID
---@param count int?
---@param hidden? boolean
---@return data.GiveItemModifier
function PM.give_item(item, count, hidden)
  return {
    type = "give-item",
    item = item,
    count = count,
    hidden = hidden,
  } --[[@as data.GiveItemModifier]]
end
---@alias SimpleModifierTypes
---| "artillery-range"
---| "beacon-distribution"
---| "belt-stack-size-bonus"
---| "bulk-inserter-capacity-bonus"
---| "cargo-landing-pad-count"
---| "character-build-distance"
---| "character-crafting-speed"
---| "character-health-bonus"
---| "character-inventory-slots-bonus"
---| "character-item-drop-distance"
---| "character-item-pickup-distance"
---| "character-logistic-trash-slots"
---| "character-loot-pickup-distance"
---| "character-mining-speed"
---| "character-reach-distance"
---| "character-resource-reach-distance"
---| "character-running-speed"
---| "deconstruction-time-to-live"
---| "follower-robot-lifetime"
---| "inserter-stack-size-bonus"
---| "laboratory-productivity"
---| "laboratory-speed"
---| "max-failed-attempts-per-tick-per-construction-queue"
---| "max-successful-attempts-per-tick-per-construction-queue"
---| "maximum-following-robots-count"
---| "mining-drill-productivity-bonus"
---| "train-braking-force-bonus"
---| "worker-robot-battery"
---| "worker-robot-speed"
---| "worker-robot-storage"
---@alias SimpleModifiers
---| data.ArtilleryRangeModifier
---| data.BeaconDistributionModifier
---| data.BeltStackSizeBonusModifier
---| data.BulkInserterCapacityBonusModifier
---| data.CargoLandingPadLimitModifier
---| data.CharacterBuildDistanceModifier
---| data.CharacterCraftingSpeedModifier
---| data.CharacterHealthBonusModifier
---| data.CharacterInventorySlotsBonusModifier
---| data.CharacterItemDropDistanceModifier
---| data.CharacterItemPickupDistanceModifier
---| data.CharacterLogisticTrashSlotsModifier
---| data.CharacterLootPickupDistanceModifier
---| data.CharacterMiningSpeedModifier
---| data.CharacterReachDistanceModifier
---| data.CharacterResourceReachDistanceModifier
---| data.CharacterRunningSpeedModifier
---| data.DeconstructionTimeToLiveModifier
---| data.FollowerRobotLifetimeModifier
---| data.InserterStackSizeBonusModifier
---| data.LaboratoryProductivityModifier
---| data.LaboratorySpeedModifier
---| data.MaxFailedAttemptsPerTickPerConstructionQueueModifier
---| data.MaxSuccessfulAttemptsPerTickPerConstructionQueueModifier
---| data.MaximumFollowingRobotsCountModifier
---| data.MiningDrillProductivityBonusModifier
---| data.TrainBrakingForceBonusModifier
---| data.WorkerRobotBatteryModifier
---| data.WorkerRobotSpeedModifier
---| data.WorkerRobotStorageModifier
---Shorthand for technology modifiers
---@param property SimpleModifierTypes
---@param modifier number
---@param hidden? boolean
---@return SimpleModifiers
function PM.modify(property, modifier, hidden)
  return {
    type = property,
    modifier = modifier,
    hidden = hidden,
  } --[[@as SimpleModifiers]]
end
---@alias BoolModifierTypes
---| "character-logistic-requests"
---| "unlock-circuit-network"
---| "cliff-deconstruction-enabled"
---| "create-ghost-on-entity-death"
---| "mining-with-fluid"
---| "rail-planner-allow-elevated-rails"
---| "rail-support-on-deep-oil-ocean"
---| "unlock-space-platforms"
---| "vehicle-logistics"
---@alias BoolModifiers
---| data.CharacterLogisticRequestsModifier
---| data.CircuitNetworkModifier
---| data.CliffDeconstructionEnabledModifier
---| data.CreateGhostOnEntityDeathModifier
---| data.MiningWithFluidModifier
---| data.RailPlannerAllowElevatedRailsModifier
---| data.RailSupportOnDeepOilOceanModifier
---| data.SpacePlatformsModifier
---| data.VehicleLogisticsModifier
---Shorthand for enabling features
---@param type BoolModifierTypes
---@param hidden? boolean
---@return BoolModifiers
function PM.enable(type, hidden)
  return {
    type = type,
    modifier = true,
    hidden = hidden,
  } --[[@as BoolModifiers]]
end
---Shorthand for disabling features
---@param type BoolModifierTypes
---@param hidden? boolean
---@return BoolModifiers
function PM.disable(type, hidden)
  return {
    type = type,
    modifier = false,
    hidden = hidden,
  } --[[@as BoolModifiers]]
end
---Shorthand for changing the productivity of a recipe
---@param recipe data.RecipeID
---@param change data.EffectValue
---@param hidden? boolean
---@return data.ChangeRecipeProductivityModifier
function PM.modify_recipe_productivity(recipe, change, hidden)
  return {
    type = "change-recipe-productivity",
    recipe = recipe,
    change = change,
    hidden = hidden,
  } --[[@as data.ChangeRecipeProductivityModifier]]
end
---Shorthand for modifying the damage or shooting speed of ammo
---@param type "ammo-damage"|"gun-speed"
---@param ammo_category data.AmmoCategoryID
---@param modifier number
---@param hidden? boolean
---@return data.AmmoDamageModifier|data.GunSpeedModifier
function PM.modify_ammo(type, ammo_category, modifier, hidden)
  return {
    type = type,
    ammo_category = ammo_category,
    modifier = modifier,
    hidden = hidden,
  } --[[@as data.AmmoDamageModifier|data.GunSpeedModifier]]
end
---Shorthand for modifying the turret damage(?)
---@param turret_id data.EntityID
---@param modifier number
---@param hidden? boolean
---@return data.TurretAttackModifier
function PM.modify_turret(turret_id, modifier, hidden)
  return {
    type = "turret-attack",
    turret_id = turret_id,
    modifier = modifier,
    hidden = hidden,
  } --[[@as data.TurretAttackModifier]]
end
---Shorthand for an dummy modifier
---@param hidden? boolean
---@return data.NothingModifier
function PM.modify_nothing(hidden)
  return {
    type = "nothing",
    hidden = hidden,
  } --[[@as data.NothingModifier]]
end

--MARK: Custom Modifiers

---@type table<string, data.IconData[]>
local custom_modifiers = PM_Global.custom_modifiers or {}
PM_Global.custom_modifiers = custom_modifiers

---Defines the icon of the custom modifier when later used by `PM.custom_modifier`
---@see Pennyisms.custom_modifier
---@param name string
---@param icons data.IconData[]
function PM.define_modifier(name, icons)
  if custom_modifiers[name] then
    error("Custom modifier already defined: "..name)
  end

  custom_modifiers[name] = icons
end

---Shorthand for a custom modifier. To have an icon defined, please use `PM.define_modifier`
---@see Pennyisms.define_modifier
---@param name string
---@param param number
---@param hidden? boolean
---@return data.NothingModifier
function PM.custom_modifier(name, param, hidden)
  local icons = custom_modifiers[name]
  if not icons then log("Custom modifer was used without defining an icon for it: "..name) end
  return {
    type = "nothing",
    effect_description = {"pm-modifier."..name, tostring(param)},
    hidden = hidden,
    icons = icons,
  }--[[@as data.NothingModifier]]
end

---Go over the effects of a technology and add up the numbers of the given custom modifier.
---@param technology LuaTechnology|LuaTechnologyPrototype
---@return number change
function PM.get_custom_modification(name, technology)
  if technology.object_name == "LuaTechnology" then
    technology = technology.prototype
  end
  local effects = technology.effects
  local locale_key = "pm-modifier."..name

  local change = 0
  for _, modifier in pairs(effects) do
    if modifier.type == "nothing"
    and modifier.effect_description[1] == locale_key then
      local num = tonumber(modifier.effect_description[2])
      ---@cast num int
      change = change + num
    end
  end

  return change
end

--MARK: Module Effects

---Returns an effect type limitation of every effect
---@return data.EffectTypeLimitation
function PM.all_effects()
  return {
    "speed",
    "productivity",
    "consumption",
    "pollution",
    "quality",
  }--[[@as data.EffectTypeLimitation]]
end

---Returns all effects except the given ones
---@param ... data.EffectTypeLimitation
---@return data.EffectTypeLimitation[]
function PM.all_effects_but(...)
  ---@type table<data.EffectTypeLimitation,true>
  local effects = {
    ["speed"] = true,
    ["productivity"] = true,
    ["consumption"] = true,
    ["pollution"] = true,
    ["quality"] = true,
  }
  for _, effect in pairs({...}) do
    effects[effect] = nil
  end
  ---@type data.EffectTypeLimitation[]
  local limitation, count = {}, 0
  for effect in pairs(effects) do
    count = count + 1
    limitation[count] = effect
  end

  return limitation
end

---Returns an array of the given effects
---
---Only exists to get intellisense to help you fill the values,
---as well as to match the other functions
---@param ... data.EffectTypeLimitation
---@return data.EffectTypeLimitation[]
function PM.effects(...)
  return {...}
end

--MARK: Module Categories

---@param blacklist? data.ModuleCategoryID[]
---@return data.ModuleCategoryID[]
function PM.all_module_categories(blacklist)
  local blacklist_lookup = PM.array_to_lookup(blacklist or {})

  local list, count = {}, 0
  for category, _ in pairs(data.raw["module-category"]) do
    if not blacklist_lookup[category] then
      count = count + 1
      list[count] = category
    end
  end

  return list
end

---@param list data.ModuleCategoryID[]
---@param blacklist data.ModuleCategoryID[]
---@return data.ModuleCategoryID[]
function PM.remove_module_categories(list, blacklist)
  if not list then
    return PM.all_module_categories(blacklist)
  end

  local blacklist_lookup = PM.array_to_lookup(blacklist)
  for i = #list, 1, -1 do
    if blacklist_lookup[list[i]] then
      table.remove(list, i)
    end
  end

  return list
end

---@param list? data.ModuleCategoryID[]
---@param new_categories data.ModuleCategoryID[]
---@return data.ModuleCategoryID[]
function PM.add_module_categories(list, new_categories)
  if not list then
    return PM.all_module_categories()
  end

  local whitelist_lookup = PM.array_to_lookup(new_categories)
  for _, category in pairs(list) do
    whitelist_lookup[category] = nil
  end

  local count = #list
  for category in pairs(whitelist_lookup) do
    count = count + 1
    list[count] = category
  end
  return list
end

--MARK: Trigger

---Will create an instant and direct script trigger if not given a trigger
---
---If given a trigger, it will try and find a direct trigger to add a delivery to. Otherwise, will add a trigger
---
---You *have* to overwrite where you got the trigger from, as it converts everything into the array format
---@param effect_id string
---@param triggers data.Trigger?
---@return data.Trigger
---@nodiscard
function PM.script_trigger(effect_id, triggers)
  -- Return trigger directly if not given one
  if not triggers then
    return {{
      type = "direct",
      action_delivery = PM.script_trigger_delivery(effect_id)
    }--[[@as data.DirectTriggerItem]]}
  end

  -- Make sure it's an array
  if triggers.type then
    triggers = {triggers}
  end

  -- Find a direct trigger to add to the delivery
  local has_direct = false
  for _, trigger in pairs(triggers) do
    if trigger.type == "direct" then
      has_direct = true
      trigger.action_delivery = PM.script_trigger_delivery(effect_id, trigger.action_delivery)
      break
    end
  end

  -- Create new trigger item if there was no direct
  if not has_direct then
    triggers[#triggers+1] = {
      type = "direct",
      action_delivery = PM.script_trigger_delivery(effect_id)
    }
  end

  ---@cast triggers data.Trigger
  -- return triggers to overwrite
  return triggers
end

---Will create an instant script delivery if not given a delivery
---
---If given a delivery, it will try and find an instant delivery to add an effects to. Otherwise, will add an instant script delivery
---
---You *have* to overwrite where you got the delivery from, as it converts everything into the array format
---@param effect_id string
---@param deliveries data.TriggerDelivery[]|data.TriggerDelivery?
---@return data.TriggerDelivery[]
---@nodiscard
function PM.script_trigger_delivery(effect_id, deliveries)
  -- Return delivery directly if not given one
  if not deliveries then
    return {{
      type = "instant",
      source_effects = PM.script_trigger_effect(effect_id)
    }--[[@as data.InstantTriggerDelivery]]}
  end

  -- Make sure it's an array
  if deliveries.type then
    deliveries = {deliveries}
  end

  -- Find an instant delivery to add to the effects
  local has_instant = false
  for _, delivery in pairs(deliveries) do
    if delivery.type == "instant" then
      has_instant = true
      delivery.source_effects = PM.script_trigger_effect(effect_id, delivery.source_effects)
      break
    end
  end

  -- Create new delivery item if there was no instant
  if not has_instant then
    deliveries[#deliveries+1] = ({
      type = "instant",
      source_effects = PM.script_trigger_effect(effect_id)
    }--[[@as data.InstantTriggerDelivery]])
  end

  ---@cast deliveries data.TriggerDelivery[]
  -- return deliveries to overwrite
  return deliveries
end

---Will create a script effect if not given an effect
---
---If given a effect, it will append a script effect to the array (converting if not already an array)
---
---You *have* to overwrite where you got the effect from, as it converts everything into the array format
---@param effect_id string
---@param effects data.TriggerEffect[]|data.TriggerEffect?
---@return data.TriggerEffect[]
---@nodiscard
function PM.script_trigger_effect(effect_id, effects)
  -- Return effect directly if not given one
  if not effects then
    return {{
      type = "script",
      effect_id = effect_id,
    }--[[@as data.ScriptTriggerEffectItem]]}
  end

  -- Make sure it's an array
  if effects.type then
    effects = {effects}
  end

  -- Create new effect
  effects[#effects+1] = {
    type = "script",
    effect_id = effect_id,
  }

  ---@cast effects data.TriggerEffect[]
  -- return effects to overwrite
  return effects
end

--MARK: Prototype fetching

--FIXME: Make this use the same generics that FMTK will eventually output

--- @overload fun(base_type: "achievement", name: string): data.AchievementPrototype
--- @overload fun(base_type: "active-trigger", name: string): data.ActiveTriggerPrototype
--- @overload fun(base_type: "airborne-pollutant", name: string): data.AirbornePollutantPrototype
--- @overload fun(base_type: "ambient-sound", name: string): data.AmbientSound
--- @overload fun(base_type: "ammo-category", name: string): data.AmmoCategory
--- @overload fun(base_type: "animation", name: string): data.AnimationPrototype
--- @overload fun(base_type: "asteroid-chunk", name: string): data.AsteroidChunkPrototype
--- @overload fun(base_type: "autoplace-control", name: string): data.AutoplaceSpecification
--- @overload fun(base_type: "burner-usage", name: string): data.BurnerUsagePrototype
--- @overload fun(base_type: "collision-layer", name: string): data.CollisionLayerPrototype
--- @overload fun(base_type: "custom-event", name: string): data.CustomEventPrototype
--- @overload fun(base_type: "custom-input", name: string): data.CustomInputPrototype
--- @overload fun(base_type: "damage-type", name: string): data.DamageType
--- @overload fun(base_type: "decorative", name: string): data.DecorativePrototype
--- @overload fun(base_type: "deliver-category", name: string): data.DeliverCategory
--- @overload fun(base_type: "deliver-impact-combination", name: string): data.DeliverImpactCombination
--- @overload fun(base_type: "editor-controller", name: string): data.EditorControllerPrototype
--- @overload fun(base_type: "entity", name: string): data.EntityPrototype
--- @overload fun(base_type: "equipment", name: string): data.EquipmentPrototype
--- @overload fun(base_type: "equipment-category", name: string): data.EquipmentCategory
--- @overload fun(base_type: "equipment-grid", name: string): data.EquipmentGridPrototype
--- @overload fun(base_type: "fluid", name: string): data.FluidPrototype
--- @overload fun(base_type: "font", name: string): data.FontPrototype
--- @overload fun(base_type: "fuel-category", name: string): data.FuelCategory
--- @overload fun(base_type: "god-controller", name: string): data.GodControllerPrototype
--- @overload fun(base_type: "gui-style", name: string): data.GuiStyle
--- @overload fun(base_type: "impact-category", name: string): data.ImpactCategory
--- @overload fun(base_type: "item", name: string): data.ItemPrototype
--- @overload fun(base_type: "item-group", name: string): data.ItemGroup
--- @overload fun(base_type: "item-subgroup", name: string): data.ItemSubGroup
--- @overload fun(base_type: "map-gen-presets", name: string): data.MapGenPresets
--- @overload fun(base_type: "map-settings", name: string): data.MapSettings
--- @overload fun(base_type: "module-category", name: string): data.ModuleCategory
--- @overload fun(base_type: "mouse-cursor", name: string): data.MouseCursor
--- @overload fun(base_type: "noise-expression", name: string): data.NamedNoiseExpression
--- @overload fun(base_type: "noise-function", name: string): data.NamedNoiseFunction
--- @overload fun(base_type: "particle", name: string): data.ParticlePrototype
--- @overload fun(base_type: "procession", name: string): data.ProcessionPrototype
--- @overload fun(base_type: "procession-layer-inheritance-group", name: string): data.ProcessionLayerInheritanceGroup
--- @overload fun(base_type: "quality", name: string): data.QualityPrototype
--- @overload fun(base_type: "recipe", name: string): data.RecipePrototype
--- @overload fun(base_type: "recipe-category", name: string): data.RecipeCategory
--- @overload fun(base_type: "remote-controller", name: string): data.RemoteControllerPrototype
--- @overload fun(base_type: "resource-category", name: string): data.ResourceCategory
--- @overload fun(base_type: "shortcut", name: string): data.ShortcutPrototype
--- @overload fun(base_type: "sound", name: string): data.SoundPrototype
--- @overload fun(base_type: "space-connection", name: string): data.SpaceConnectionPrototype
--- @overload fun(base_type: "space-location", name: string): data.SpaceLocationPrototype
--- @overload fun(base_type: "spectator-controller", name: string): data.SpectatorControllerPrototype
--- @overload fun(base_type: "sprite", name: string): data.SpritePrototype
--- @overload fun(base_type: "surface", name: string): data.SurfacePrototype
--- @overload fun(base_type: "surface-property", name: string): data.SurfacePropertyPrototype
--- @overload fun(base_type: "technology", name: string): data.TechnologyPrototype
--- @overload fun(base_type: "tile", name: string): data.TilePrototype
--- @overload fun(base_type: "tile-effect", name: string): data.TileEffectDefinition
--- @overload fun(base_type: "tips-and-tricks-item", name: string): data.TipsAndTricksItem
--- @overload fun(base_type: "tips-and-tricks-item-category", name: string): data.TipsAndTricksItemCategory
--- @overload fun(base_type: "trigger-target-type", name: string): data.TriggerTargetType
--- @overload fun(base_type: "trivial-smoke", name: string): data.TrivialSmokePrototype
--- @overload fun(base_type: "tutorial", name: string): data.TutorialDefinition
--- @overload fun(base_type: "utility-constants", name: string): data.UtilityConstants
--- @overload fun(base_type: "utility-sounds", name: string): data.UtilitySounds
--- @overload fun(base_type: "utility-sprites", name: string): data.UtilitySounds
--- @overload fun(base_type: "virtual-signal", name: string): data.VirtualSignalPrototype
--- @overload fun(base_type: string, name: string): data.PrototypeBase
function PM.get_prototype(base_type, name)
  for type in pairs(defines.prototypes[base_type]) do
    local type_lookup = data.raw[type]
    if type_lookup then
      local proto = type_lookup[name]
      if proto then return proto end
    end
  end
  error("'"..base_type.."' prototype '"..name.."' was not found")
end

--- @type table<string, string?>
local base_type_lookup = {}
for base_type, derived_types in pairs(defines.prototypes) do
  for derived_type in pairs(derived_types) do
    base_type_lookup[derived_type] = base_type
  end
end

---@param type string
---@return string?
function PM.get_base_type(type)
  return base_type_lookup[type]
end

--MARK: Locale manipulation

--- This section was taken from flib and lightly modified
--- License:
-- Copyright (c) 2020 raiguard

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

--- Returns the localised name of the given prototype.
--- @overload fun(prototype: data.PrototypeBase): data.LocalisedString
--- @overload fun(base_type: string, name: string): data.LocalisedString
function PM.locale_of(prototype, name)
  -- In this case, `prototype` is actually `base_type`.
  if type(prototype) == "string" then
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
    return PM.locale_of(PM.get_prototype(prototype, name) --[[@as data.PrototypeBase]])
  end
  if prototype.type == "recipe" then
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
    return PM.locale_of_recipe(prototype --[[@as data.RecipePrototype]])
  elseif defines.prototypes.item[prototype.type] then
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
    return PM.locale_of_item(prototype --[[@as data.ItemPrototype]])
  else
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
    return prototype.localised_name or { PM.get_base_type(prototype.type) .. "-name." .. prototype.name }
  end
end

--- Returns the localised name of the given item.
--- @param item data.ItemPrototype
--- @return data.LocalisedString
function PM.locale_of_item(item)
  if not defines.prototypes.item[item.type] then
    error("Given prototype is not an item: " .. serpent.block(item))
  end
  if item.localised_name then
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
    return item.localised_name
  end
  local type_name = "item"
  --- @type data.PrototypeBase?
  local prototype
  if item.place_result then
    type_name = "entity"
    prototype = PM.get_prototype("entity", item.place_result) --[[@as data.PrototypeBase]]
  elseif item.place_as_equipment_result then
    type_name = "equipment"
    prototype = PM.get_prototype("equipment", item.place_as_equipment_result) --[[@as data.PrototypeBase]]
  elseif item.place_as_tile then
    local tile_prototype = data.raw.tile[item.place_as_tile.result]
    -- Tiles with variations don't have a localised name
    if tile_prototype and tile_prototype.localised_name then
      prototype = tile_prototype
      type_name = "tile"
    end
  end
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
  return prototype and prototype.localised_name or { type_name .. "-name." .. item.name }
end

--- Returns the localised name of the given recipe.
--- @param recipe data.RecipePrototype
--- @return data.LocalisedString
function PM.locale_of_recipe(recipe)
  if recipe.type ~= "recipe" then
    error("Given prototype is not an recipe: " .. serpent.block(recipe))
  end
  if recipe.localised_name then
    ---@diagnostic disable-next-line: return-type-mismatch (type recursion)
    return recipe.localised_name
  end
  local main_product = recipe.main_product -- LuaLS gets confused if we don't assign to a local.
  if main_product == "" then
    return { "recipe-name." .. recipe.name }
  elseif main_product and main_product == recipe.name then
    return PM.locale_of_item(PM.get_prototype("item", main_product))
  end
  local results = recipe.results
  if results and #results == 1 and results[1].name == recipe.name then
    return PM.locale_of_item(PM.get_prototype("item", results[1].name))
  end
  return { "recipe-name." .. recipe.name }
end


--MARK: Runtime library

---@type boolean?
local has_better_chat = nil
local send_levels = {
  ["LuaGameScript"] = "global",
  ["LuaForce"] = "force",
  ["LuaPlayer"] = "player",
  ["LuaSurface"] = "surface",
}
--- Safely attempts to print via the Better Chatting's interface
---@param recipient LuaGameScript|LuaForce|LuaPlayer|LuaSurface
---@param msg LocalisedString
---@param print_settings PrintSettings?
function PM.compat_send(recipient, msg, print_settings)
  if has_better_chat == nil then
    local better_chat = remote.interfaces["better-chat"]
		has_better_chat = better_chat and better_chat["send"] or false
  end

  if not has_better_chat then return recipient.print(msg, print_settings) end
  print_settings = print_settings or {}


  local send_level = send_levels[recipient.object_name]
  ---@type int?
  local send_index
  if send_level ~= "global" then
    send_index = recipient.index
    if not send_index then
      error("Invalid Recipient", 2)
    end
  end

  remote.call("better-chat", "send", {
    message = msg,
    send_level = send_level,
    color = print_settings.color,
    recipient = send_index,
    clear = false,

    sound = print_settings.sound,
    sound_path = print_settings.sound_path,
    volume_modifier = print_settings.volume_modifier
  })
end

PM.compound_events = {}

---@alias Pennyisms.BuiltEventData
---| EventData.on_built_entity
---| EventData.on_robot_built_entity
---| EventData.on_space_platform_built_entity
---| EventData.script_raised_built
---| EventData.script_raised_revive
---| EventData.on_entity_cloned
---@param event_handler event_handler.events?
---@param handler fun(event:Pennyisms.BuiltEventData) Make sure your handler also handles `entity.destination`
function PM.compound_events.built_events(event_handler, handler)
  if not event_handler then error("Given events map is nil") end
  for _, event_id in pairs{
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
    defines.events.on_entity_cloned
  } do
    event_handler[event_id] = handler
  end
end

return PM
-- as it says on the tin