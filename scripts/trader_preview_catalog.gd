extends RefCounted
# Source-owned, read-only examples. No instance IDs, live sellers, prices or saved listings.
const DEFINITIONS={
 "psy":{"shop_id":"psy","title":"PSY · GEAR & ARMOR","emblem":"◇","role":"Equipment previews · no purchases or repairs yet","tabs":["gear"],"help":"Helmet, vest, pack and rig are display previews. No protection or extra carrying capacity is granted."},
 "dan":{"shop_id":"dan","title":"DAN · PLAYER MARKETPLACE","emblem":"▤","role":"Interactive preview · sample listings only","tabs":["browse","my listings","how it works"],"help":"Browse and search demo listings. Buying, bidding and posting are coming soon."},
 "atlas":{"shop_id":"atlas","title":"ATLAS · RECOVERY","emblem":"▣","role":"Recovery overview · service coming soon","tabs":["overview"],"help":"No recovery, healing or paid service is available. The tagged kits and lockers are display props."}
}
static func definition(id:String)->Dictionary:return DEFINITIONS.get(id,{}).duplicate(true)
static func entry(id:String,label:String,category:String,description:String,reason:String)->Dictionary:
 return {"id":id,"name":label,"category":category,"description":description,"price":null,"owned":0,"enabled":false,"reason":reason,"max_quantity":1,"space_per_unit":0}
static func rows(id:String,tab:String)->Array:
 if id=="psy":return [
  entry("helmet_basic","Basic helmet","Head gear","Planned equipment slot: helmet. This is a catalogue preview, not an owned or equippable item.","Preview only · equipment use and persistence are not available."),
  entry("armor_basic_vest","Basic armor vest","Body gear","Planned equipment slot: body armor. No protection statistics or damage reduction are implemented.","Preview only · cannot buy or equip."),
  entry("backpack_basic","Field pack","Carry gear","Planned equipment slot: backpack. This preview does not add carried space.","Preview only · carrying behavior has not been defined."),
  entry("rig_basic","Utility rig","Carry gear","Planned equipment slot: tactical rig. No pouch inventory or additional slots are available.","Preview only · cannot buy, equip or repair.")]
 if id=="atlas":return [entry("recovery_preview","Recovery coming soon","Overview","Atlas's stand is reserved for a future recovery service. The ledger, tagged parcels and return lockers are scenery.\n\nThere is no lost-item collection, retrieval timer, healing or recovery fee in this build.","Unavailable · no items or credits will change.")]
 if id!="dan":return []
 if tab=="my listings":return [entry("marketplace_empty","No listings in this preview","My listings","You have no live marketplace listings. Posting is disabled, and no inventory is reserved.\n\nThe Browse tab contains clearly marked examples only.","Post listing unavailable · marketplace coming soon.")]
 if tab=="how it works":return [entry("marketplace_help","How the preview works","Help","Browse demo listings, filter by category or search by item name, and select a row to read its details.\n\nAll entries are labelled Demo listing and Sample seller. They do not represent other players.\n\nBuy now, Bid and Post listing are disabled. No bids, fees, deliveries, countdowns or live listings exist yet.","Preview only · no currency, inventory, listing storage or network changes.")]
 return [
  entry("demo_timber","Demo listing · Timber bundle","Materials","Demo listing\nSample seller\nExample quantity: 3 timber\n\nA layout example for a future player marketplace. This is not stock for sale.","Buy now and Bid unavailable · coming soon."),
  entry("demo_stone","Demo listing · Sorted stone","Materials","Demo listing\nSample seller\nExample quantity: 2 stone\n\nA layout example only. No material is available to transfer.","Buy now and Bid unavailable · coming soon."),
  entry("demo_jacket","Demo listing · Folded jacket","Clothing","Demo listing\nSample seller\nExample quantity: 1 jacket\n\nThis is not one of your owned garments. Clothing and dye services are at the tailor.","Buy now and Bid unavailable · coming soon.")]
