extends RefCounted
# Review proposal prices are confined to ordinary fish. Paid food, herbs and
# unlocks remain previews until a real use is defined. Never price previews at 0.
const VERSION=1
const FISH_BUY=8
const FISH_SELL=3
const STARTER='recipe_griddle_fish'
const OUTPUT='cooked_griddle_fish'
static func definition(service:String)->Dictionary:
 if service=='craft':
  return {'shop_id':'cook_griddle','title':'CAMPFIRE GRIDDLE','emblem':'GRIDDLE','role':'Prepare carried fish · Display samples only','tabs':['craft'],'help':'Turn ordinary river fish into a saved display sample. Not edible or sellable; no food benefits.'}
 return {'shop_id':'cook_vendor','title':'COOKHOUSE','emblem':'COOK','role':'Cooking supplies · Ordinary fish and recipe previews','tabs':['buy','sell'],'help':'Buy or sell ordinary river fish. Use the nearby griddle for display samples; eating is unavailable.'}
static func rows(action:String,inventory)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 if action=='craft':
  result.append({'id':STARTER,'name':'Simple griddle fish','category':'Known recipe','description':'1 river fish → 1 griddle fish display sample. Carried and saved; not edible or sellable. No food benefits.','price':0,'owned':inventory.amount('carried','river_fish'),'enabled':inventory.knows_recipe(STARTER) and inventory.amount('carried','river_fish')>0,'reason':'Needs 1 carried ordinary river fish. Quest stream fish is protected.','icon':'res://assets/ui/production_v095/cooked_griddle_fish.res','unit_label':'sample','space_per_unit':0,'max_quantity':maxi(1,inventory.amount('carried','river_fish'))})
  result.append(preview('recipe_herbed_fish','Herbed fish','Recipe preview','1 river fish + 1 culinary herb. Unavailable until cooked food has a defined use.'))
  result.append(preview('recipe_toasted_herbs','Toasted herbs','Recipe preview','1 culinary herb. Unavailable until cooked food has a defined use.'))
 elif action=='sell':
  result.append({'id':'river_fish','icon':'res://assets/ui/production_v095/river_fish.res','name':'River fish','category':'Ordinary ingredient','description':'Sell ordinary carried fish only. Quest stream fish, prepared samples, equipment and stored goods are protected.','price':FISH_SELL,'owned':inventory.amount('carried','river_fish'),'enabled':inventory.amount('carried','river_fish')>0,'reason':'No carried ordinary river fish. Quest fish is not accepted.'})
 else:
  result.append({'id':'river_fish','icon':'res://assets/ui/production_v095/river_fish.res','name':'River fish','category':'Ordinary ingredient','description':'Ordinary fish for the nearby griddle. Its current output is a carried display sample, not an edible meal. You can also catch ordinary fish with an owned pole.','price':FISH_BUY,'owned':inventory.amount('carried','river_fish'),'enabled':inventory.used('carried')<inventory.capacity('carried'),'reason':'Bag full · make 1 carried space.'})
  result.append({'id':STARTER,'icon':'res://assets/ui/production_v095/cooked_griddle_fish.res','name':'Simple griddle fish recipe','category':'Starter knowledge','description':'Free starter knowledge. 1 ordinary river fish → 1 persistent display sample.','price':0,'owned':1,'enabled':false,'reason':'Already learned · use the nearby griddle.'})
  result.append(preview('culinary_herb','Culinary herbs','Ingredient preview','Not sold until its production recipes have a defined output use.'))
  result.append(preview('cooking_salt','Cooking salt','Ingredient preview','Preview only · not yet a persistent or usable ingredient. Buying and selling are unavailable.'))
  result.append(preview('cooking_oil','Cooking oil','Ingredient preview','Preview only · not yet a persistent or usable ingredient. Buying and selling are unavailable.'))
  result.append(preview('recipe_herbed_fish','Herbed fish recipe','Recipe preview','Unavailable until ingredients, recipe output and food use are complete.'))
  result.append(preview('recipe_toasted_herbs','Toasted herbs recipe','Recipe preview','Unavailable until ingredients, recipe output and food use are complete.'))
  result.append(preview(OUTPUT,'Griddle fish','Food preview','Prepared-food purchases and sales are unavailable. You can make a clearly labeled display sample for free at the griddle.'))
 return result
static func preview(id:String,title:String,category:String,reason:String)->Dictionary:
 return {'id':id,'name':title,'category':category,'description':reason,'price':null,'owned':0,'enabled':false,'reason':reason}
