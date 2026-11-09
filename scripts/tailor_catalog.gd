extends RefCounted
# Exact provisional prices/formulas from the approved Traders-and-Graphics review.
const GARMENTS={"basic_jacket":18,"basic_pants":14,"basic_gloves":8,"basic_boots":12}
const MATERIALS={"cloth_linen":4,"thread_spool":2}
const PATTERNS={
 "pattern_basic_gloves":{"price":0,"cloth":2,"output":"basic_gloves"},
 "pattern_basic_pants":{"price":10,"cloth":3,"output":"basic_pants"},
 "pattern_basic_jacket":{"price":14,"cloth":4,"output":"basic_jacket"}
}
const NAMES={"basic_jacket":"Basic jacket","basic_pants":"Basic pants","basic_gloves":"Basic gloves","basic_boots":"Basic boots","cloth_linen":"Linen cloth","thread_spool":"Thread spool","pattern_basic_gloves":"Basic gloves pattern","pattern_basic_pants":"Basic pants pattern","pattern_basic_jacket":"Basic jacket pattern"}
static func rows(inventory,action:String="buy")->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 if action!="sell":
  for id in GARMENTS:
   var owned=0
   for entry in inventory.equipment_owned.values():
    if entry.definition_id==id:owned+=1
   result.append({"id":id,"name":NAMES[id],"category":"Clothing","description":"Additional cosmetic garment, delivered to carried inventory. No armor or storage bonus. Your free starter outfit remains separate."+(" Boots have no dye channel." if id=="basic_boots" else " Fabric can be dyed with an unused free slot allowance."),"price":GARMENTS[id],"owned":owned,"enabled":true,"reason":"","icon":"res://assets/ui/inventory_"+id.trim_prefix("basic_")+".svg"})
 for id in MATERIALS:
  var count=inventory.amount("carried",id)
  result.append({"id":id,"name":NAMES[id],"category":"Materials","description":"Consumed by a successful tailoring recipe. One carried unit each. Thread is an ingredient, not a reusable tool.","price":1 if action=="sell" else MATERIALS[id],"owned":count,"enabled":action!="sell" or count>0,"reason":"No carried units to sell." if action=="sell" and count==0 else ""})
 if action!="sell":
  for id in PATTERNS:
   var p=PATTERNS[id];var known=inventory.knows_recipe(id)
   result.append({"id":id,"name":NAMES[id],"category":"Patterns","description":"Learn once; no carried space. %d linen cloth + 1 thread spool → 1 %s."%[p.cloth,NAMES[p.output].to_lower()],"price":p.price,"max_quantity":1,"space_per_unit":0,"owned":1 if known else 0,"enabled":not known,"reason":"Already learned." if known else ""})
  result.append({"id":"shirt_basic","name":"Basic shirt","category":"Clothing","description":"Future garment. A shirt slot or layering rule must be defined first.","price":null,"owned":0,"enabled":false,"reason":"Preview only. No shirt slot or sale exists."})
  result.append({"id":"dye_palette_future","name":"Pigment packets","category":"Materials","description":"Named swatches are available in Dye. Pigment consumption is not defined.","price":null,"owned":0,"enabled":false,"reason":"Preview only. No pigment price or consumption rule."})
 return result
