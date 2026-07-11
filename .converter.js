//MARK: UNMAINTAINED
// This is unmaintained and out of date. Good luck.

const fs = require('fs').promises

/**
 * OUTDATED
 * @type {[RegExp, string][]}
 */
const regex_and_replace_array = [
  //MARK: Ingredients
  [ // Ingredient Shorthand
    /(?<=ingredients =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?<name>"[^"]*")\s*,\s*(?<amount>\d+)\s*}/g,
    "PM.ingredient($<name>, $<amount>)"
  ],
  [ // Ingredient Item
    /(?<=ingredients =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?![^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ingredient($<name>, $<amount>)'
  ],
  [ // Catalyst Ingredient Item
    /(?<=ingredients =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_ingredient($<name>, $<amount>, $<ignored_by_productivity>)'
  ],
  [ // Ingredient Fluid
    /(?<=ingredients =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?=[^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ingredient($<name>, $<amount>, "fluid")'
  ],
  [ // Catalyst Ingredient Fluid
    /(?<=ingredients =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_ingredient($<name>, $<amount>, $<ignored_by_productivity>, "fluid")'
  ],

  //MARK: Product Items
  [ // Product Shorthand
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?<name>"[^"]*")\s*,\s*(?<amount>\d+)\s*}/g,
    'PM.product($<name>, $<amount>)'
  ],
  [ // Product Item
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?![^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product($<name>, $<amount>)'
  ],
  [ // Product Item Range
    /{\s*(?![^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product_range($<name>, $<amount_min>, $<amount_max>)'
  ],
  [ // Product Item Chance
    /{\s*(?![^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product_chance($<name>, $<amount>, $<probability>)'
  ],
  [ // Product Item Rance Chance - lmao
    /{\s*(?![^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product_range_chance($<name>, $<amount_min>, $<amount_max>, $<probability>)'
  ],

  //MARK: Product Fluids
  [ // Product Fluid
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?=[^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product($<name>, $<amount>, "fluid")'
  ],
  [ // Product Fluid Range
    /{\s*(?=[^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product_range($<name>, $<amount_min>, $<amount_max>, "fluid")'
  ],
  [ // Product Fluid Chance
    /{\s*(?=[^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product_chance($<name>, $<amount>, $<probability>, "fluid")'
  ],
  [ // Product Fluid Range Chance
    /{\s*(?=[^{}]*type = "fluid")(?![^{}]*ignored_by_productivity =)(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.product_range_chance($<name>, $<amount_min>, $<amount_max>, $<probability>, "fluid")'
  ],


  //MARK: Catalyst Items
  [ // Catalyst Item
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst($<name>, $<amount>, $<ignored_by_productivity>)'
  ],
  [ // Catalyst Item Range
    /{\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_range($<name>, $<amount_min>, $<amount_max>, $<ignored_by_productivity>)'
  ],
  [ // Catalyst Item Chance
    /{\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_chance($<name>, $<amount>, $<probability>, $<ignored_by_productivity>)'
  ],
  [ // Catalyst Item Rance Chance
    /{\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_range_chance($<name>, $<amount_min>, $<amount_max>, $<probability>, $<ignored_by_productivity>)'
  ],

  //MARK: Catalyst Fluids
  [ // Catalyst Fluid
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst($<name>, $<amount>, $<ignored_by_productivity>, "fluid")'
  ],
  [ // Catalyst Fluid Range
    /{\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_range($<name>, $<amount_min>, $<amount_max>, $<ignored_by_productivity>, "fluid")'
  ],
  [ // Catalyst Fluid Chance
    /{\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_chance($<name>, $<amount>, $<probability>, $<ignored_by_productivity>, "fluid")'
  ],
  [ // Catalyst Fluid Range Chance
    /{\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_productivity = (?<ignored_by_productivity>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.catalyst_range_chance($<name>, $<amount_min>, $<amount_max>, $<probability>, $<ignored_by_productivity>, "fluid")'
  ],

  //MARK: Ignored Items
  [ // Ignored Item
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored($<name>, $<amount>, $<ignored_by_stats>)'
  ],
  [ // Ignored Item Range
    /{\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored_range($<name>, $<amount_min>, $<amount_max>, $<ignored_by_stats>)'
  ],
  [ // Ignored Item Chance
    /{\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored_chance($<name>, $<amount>, $<probability>, $<ignored_by_stats>)'
  ],
  [ // Ignored Item Rance Chance
    /{\s*(?![^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored_range_chance($<name>, $<amount_min>, $<amount_max>, $<probability>, $<ignored_by_stats>)'
  ],

  //MARK: Catalyst Fluids
  [ // Ignored Fluid
    /(?<=results =\s+{(?:[^{}]|{[^{}]*})*?){\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored($<name>, $<amount>, $<ignored_by_stats>, "fluid")'
  ],
  [ // Ignored Fluid Range
    /{\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?![^{}]*probability =)(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored_range($<name>, $<amount_min>, $<amount_max>, $<ignored_by_stats>, "fluid")'
  ],
  [ // Ignored Fluid Chance
    /{\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*(?<!_)amount = (?<amount>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored_chance($<name>, $<amount>, $<probability>, $<ignored_by_stats>, "fluid")'
  ],
  [ // Ignored Fluid Range Chance
    /{\s*(?=[^{}]*type = "fluid")(?=[^{}]*ignored_by_stats = (?<ignored_by_stats>\d+(?:\.\d+)?))(?=[^{}]*probability = (?<probability>\d+(?:\.\d+)?))(?=[^{}]*name = (?<name>"[^"]*"))(?=[^{}]*amount_min = (?<amount_min>\d+(?:\.\d+)?))(?=[^{}]*amount_max = (?<amount_max>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.ignored_range_chance($<name>, $<amount_min>, $<amount_max>, $<probability>, $<ignored_by_stats>, "fluid")'
  ],

  //MARK: Technology Effects
  [ // Unlock Recipe
    /{\s*(?=[^{}]*type = "unlock-recipe")(?=[^{}]*recipe = (?<recipe>"[^"]+"))[^{}]*}/g,
    'PM.unlock_recipe($<recipe>)'
  ],

  [ // Give Item
    /{\s*(?=[^{}]*type = "give-item")(?=[^{}]*item = (?<item>"[^"]+"))(?![^{}]*count =)[^{}]*}/g,
    'PM.give_item($<item>)'
  ],
  [ // Give Item w/ count
    /{\s*(?=[^{}]*type = "give-item")(?=[^{}]*item = (?<item>"[^"]+"))(?=[^{}]*count = (?<count>\d+))[^{}]*}/g,
    'PM.give_item($<item>, $<count>)'
  ],

  [ // Modify Parameter
    /{\s*(?=[^{}]*type = (?<type>"[^"]+"))(?![^{}]*ammo_category =)(?![^{}]*turret_id =)(?=[^{}]*modifier = (?<modifier>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.modify($<type>, $<modifier>)'
  ],
  [ // Modify Ammo
    /{\s*(?=[^{}]*type = (?<type>"(?:ammo-damage|gun-speed)"))(?=[^{}]*ammo_category = (?<ammo_category>"[^"]+"))(?=[^{}]*modifier = (?<modifier>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.modify_ammo($<type>, $<ammo_category>, $<modifier>)'
  ],
  [ // Modify Turret attack
    /{\s*(?=[^{}]*type = "turret-attack")(?=[^{}]*turret_id = )(?=[^{}]*modifier = (?<modifier>\d+(?:\.\d+)?))[^{}]*}/g,
    'PM.modify_turret($<turret_id>, $<modifier>)'
  ],

  [ // Modify nothing
    /{\s*(?=[^{}]*type = "nothing")[^{}]*}/g,
    'PM.modify_nothing()'
  ],
]

const regex_for_complex_replace = [
  //MARK: Old PM funcs
  // Basic product
  /PM\.product\((?<name>[^)},]+),\s*(?<amount>[^)},]+)\)/g,
  /PM\.product\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.product\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.product_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\}\)/g,
  /PM\.product_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<type>[^)},]+)\)/g,
  /PM\.product_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.product_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+)\)/g,
  /PM\.product_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.product_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.product_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+)\)/g,
  /PM\.product_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.product_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.catalyst\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<catalyst>[^)},]+)\)/g,
  /PM\.catalyst\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.catalyst\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.catalyst_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<catalyst>[^)},]+)\)/g,
  /PM\.catalyst_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.catalyst_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.catalyst_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<catalyst>[^)},]+)\)/g,
  /PM\.catalyst_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.catalyst_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.catalyst_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<catalyst>[^)},]+)\)/g,
  /PM\.catalyst_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.catalyst_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<catalyst>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.ignored\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<ignored>[^)},]+)\)/g,
  /PM\.ignored\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.ignored\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.ignored_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<ignored>[^)},]+)\)/g,
  /PM\.ignored_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.ignored_range\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.ignored_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<ignored>[^)},]+)\)/g,
  /PM\.ignored_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.ignored_chance\((?<name>[^)},]+),\s*(?<amount>[^)},]+),\s*(?<probability>[^)},]+),\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

  /PM\.ignored_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<ignored>[^)},]+)\)/g,
  /PM\.ignored_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+)\)/g,
  /PM\.ignored_range_chance\((?<name>[^)},]+),\s*\{(?<amount_min>[^)},]+),\s*(?<amount_max>[^)},]+)\},\s*(?<probability>[^)},]+),\s*(?<ignored>[^)},]+),\s*(?<type>[^)},]+),\s*(?<index>[^)},]+)\)/g,

]

if (process.argv.length !== 3) {
  console.error("Takes in a single argument that is the path of the file being modified")
  process.exit(1)
}

/**
 * @param {string} filepath
 * @returns Promise<string>
 */
async function readFile(filepath) {
  const data = await fs.readFile(filepath);
  return data.toString();
}

/**
 * @typedef Product
 * @prop {string} name
 * @prop {"item"|"fluid"|undefined} type
 * @prop {string|undefined} amount
 * @prop {string|undefined} amount_min
 * @prop {string|undefined} amount_max
 * @prop {string|undefined} probability
 * @prop {string|undefined} min_probability
 * @prop {string|undefined} max_probability
 * @prop {string|undefined} catalyst
 * @prop {string|undefined} ignored
 * @prop {string|undefined} index
 * @prop {string|undefined} optional_indexes
 * @prop {string|undefined} temperature
 * @prop {string|undefined} buffer
 * @prop {string|undefined} extra
 * @prop {string|undefined} spoiled_fresh
 * @prop {string|undefined} spoiled_reset
 * @prop {string|undefined} quality_min
 * @prop {string|undefined} quality_max
 * @prop {string|undefined} quality_bump
 * @prop {string|undefined} static_quality
 * @prop {string|undefined} can_quality
 */

/**
 * @param {Product} product
 * @return {string}
 */
function process_match_groups(product) {
  //MARK: Base
  let replacement = `PM.product(${product.name}`
  if (product.type) {
    replacement += `, ${product.type})`
  } else {
    replacement += `)`
  }

  // Amount
  if (product.amount) {
    replacement += `:amount(${product.amount})`
  } else if (product.amount_min && product.amount_max) {
    replacement += `:amount(${product.amount_min}, ${product.amount_max})`
  } else {
    throw Error("There was no ammount??")
  }

  if (product.extra) {
    replacement += `:extra(${product.extra})`
  }

  // Probability
  let has_exclusive_probability = product["min_probability"] && product["max_probability"]
  if (product.probability && product.min_probability && product.max_probability) {
    replacement += `:combined_chance(${product.probability}, ${product.min_probability}, ${product.max_probability})`
  } else if (product.probability) {
    replacement += `:chance(${product.probability})`
  } else if (product.min_probability && product.max_probability) {
    replacement += `:chance(${product.min_probability}, ${product.max_probability})`
  }

  // Catalyst
  if (product.catalyst) {
    replacement += `:catalyst(${product.catalyst}`
    if (product.can_quality) {
      replacement += `, ${product.can_quality})`
    } else {
      replacement += `)`
    }
  }

  // Ignored
  if (product.ignored) {
    replacement += `:ignored(${product.ignored})`
  }

  //MARK: Fluid
  if (product.index) {
    replacement += `:index(${product.index}`
    if (product.optional_indexes) {
      replacement += `, ${product.optional_indexes})`
    } else {
      replacement += `)`
    }
  }

  if (product.temperature) {
    replacement += `:temperature(${product.temperature})`
  }
  if (product.buffer) {
    replacement += `:buffer(${product.buffer})`
  }

  //MARK: Item
  if (product.spoiled_fresh || product.spoiled_reset) {
    let reset = product.spoiled_reset ? product.spoiled_reset : "false"
    let fresh = product.spoiled_fresh ? product.spoiled_fresh : "false"
    replacement += `:fresh(${reset}, ${fresh})`
  }

  if (product.quality_min || product.quality_max) {
    let min = product.quality_min ? product.quality_min : "nil"
    let max = product.quality_max ? product.quality_max : "nil"
    replacement += `:quality_range(${min}, ${max})`
  }

  if (product.quality_bump) {
    replacement += `:quality_bump(${product.quality_bump})`
  }

  if (product.static_quality) {
    replacement += `:static_quality(${product.static_quality})`
  }

  replacement += `:done()`
  return replacement
}


(async () => {
  let given_path = process.argv[2]
  let path_type = await fs.stat(given_path)

  let files
  if (path_type.isFile()) {
    files = [given_path]
    given_path = ""

  } else if (path_type.isDirectory()) {
    files = await fs.readdir(given_path)

  } else {
    console.error("The given path has to either be a directory or file")
    process.exit(1)
  }

  let promises = []
  for (let index = 0; index < files.length; index++) {
    const file = given_path+files[index];
    if ((await fs.stat(file)).isDirectory()) continue

    promises[promises.length] = (async () => {
      let file_contents = await readFile(file)
      
      const startTime = performance.now()
      for (const regex of regex_for_complex_replace) {
        /**
         * @typedef Replacement
         * @prop {number} start
         * @prop {number} end
         * @prop {string} replacement
         */
        /**
         * @type {Replacement[]}
         */
        let matches = []
        for (const match of file_contents.matchAll(regex)) {
          let product = match.groups
          if (!product) continue;

          matches[matches.length] = {
            start: match.index,
            end: match.index + match[0].length,
            replacement: process_match_groups(product)
          }
        }

        for (let index = matches.length-1; index >= 0 ; index--) {
          const match = matches[index];

          let start = file_contents.substring(0, match.start)
          let end = file_contents.substring(match.end)
          file_contents = start + match.replacement + end
        }
      }
      const endTime = performance.now()
      console.log(`Replaced all ingredients and products within ${file} in ${endTime-startTime} milliseconds`)

      await fs.rename(file, file+".bak")
      await fs.writeFile(file, file_contents)
    })();
  }

  await Promise.all(promises)
  console.log(`Files backed up and replaced with processed versions.`)
})();
