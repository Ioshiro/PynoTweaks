require "TimedActions/ISAddItemInRecipe"
local original_isValid = ISAddItemInRecipe.isValid
function ISAddItemInRecipe:isValid()
	local result = original_isValid(self)
	self.alreadyWarned = self.alreadyWarned or false

	if result and self.usedItem:getHungChange() < 0.0 then
		return true
	end
	
	if not self.alreadyWarned then
		self.alreadyWarned = true
		getPlayer():Say(getText("IGUI_Recipe_NoHungerFood"))
	end

	return false 
end