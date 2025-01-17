bossPowerScale = class({})

MAX_STATUS_RESIST = 75
SECONDS_TO_COMBO_BREAK = 10

function bossPowerScale:OnCreated(keys)
	self:SetHasCustomTransmitterData( true )
	self:OnRefresh()
end

function bossPowerScale:OnRefresh(keys)
	local roundNumber = math.floor( self:GetStackCount() / 100 )
	local difficulty = math.floor( ( self:GetStackCount() % 100 ) / 10 )
	local playerNumber = ( self:GetStackCount() % 10 ) / 100
	
	-- function to scale scaling down early on, ramping it up starting from round 17
	local logisticFunction = 0.1 + 1/ ( 1 + math.exp(-0.25*(roundNumber-13)) )
	
	-- remove some base armor and add it to bonus armor
	self.baseArmor = self.baseArmor or self:GetParent():GetPhysicalArmorBaseValue()
	self.bonusArmor = ( ( (1 + difficulty * 0.03) - 1 ) * 100 ) * logisticFunction + (self.baseArmor * 0.6) 
	
	self.bonusDamagePct = ( ( (1 + playerNumber * 4) * (1 + difficulty * 0.2) - 1 ) * 100 ) * logisticFunction
	self.bonusSpellDamage = ( ( (1 + difficulty * 0.25) - 1 ) * 100 ) * logisticFunction
	
	
	if difficulty >= 3 then
		self.bonusCooldownReduction = 0
		self.bonusArmor = self.bonusArmor + 5.55
		self.bonusMR = 33
		self.bonusMS = 15
	end
	
	self.treewalk = false
	self.dmgTakenSinceCheck = 0
	self.lastHPPctSinceCheck = self:GetParent():GetHealthPercent()
	self.HPRageThreshold = 2.4
	self.enrageTimer = 90
	if self:GetParent():IsConsideredHero() then 
		self.baseStatusResistance = 10
		if self:GetParent():IsConsideredHero() then
			self.baseStatusResistance = self.baseStatusResistance + 5 * difficulty
		else
			self.baseStatusResistance = self.baseStatusResistance + 1.2 * difficulty
		end
		self.actualStatusResistance = self.baseStatusResistance
		self.statusResistIncreasePerTick = ( (MAX_STATUS_RESIST - self.baseStatusResistance) / SECONDS_TO_COMBO_BREAK ) * 0.25
	end
	print( self.baseStatusResistance, "status resist" )
	self:StartIntervalThink( 0.25 )
	
	if IsServer() then 
		self:GetParent().bossOriginalModel = self:GetParent():GetModelName() 
		self:GetParent():SetPhysicalArmorBaseValue( self.baseArmor * 0.4 )
		self.bonusDamage = self:GetParent():GetAverageBaseDamage() * self.bonusDamagePct / 100
		self:SendBuffRefreshToClients()
	end
end

function bossPowerScale:OnIntervalThink()

	if IsServer() then
		self.treewalk = not self:GetParent():IsLeashed()
		if self:GetParent():IsInvulnerable() or self:GetParent():IsInvulnerable() or self:GetParent():IsOutOfGame() then return end
		self.enrageTimer = self.enrageTimer - 0.25
		if self.enrageTimer <= 0 then
			if self.lastHPPctSinceCheck - self:GetParent():GetHealthPercent() < self.HPRageThreshold then -- time to get pissed off
				self:GetParent():AddNewModifier( self:GetParent(), nil, "modifier_boss_enraged", {} )
			
			end
			self.lastHPPctSinceCheck = self:GetParent():GetHealthPercent()
			self.enrageTimer = 30
			self.dmgTakenSinceCheck = 0
		end
	end
	
	if self.baseStatusResistance then
		if self:GetParent():HasModifier("status_immune") then return end
		if self:GetParent():IsStunned() or self:GetParent():IsHexed() or self:GetParent():IsFeared()
		or self:GetParent():IsSilenced() or self:GetParent():IsDisarmed() 
		or self:GetParent():IsRooted() or self:GetParent():PassivesDisabled() then
			if self.actualStatusResistance == MAX_STATUS_RESIST then -- make status immune for 5 seconds.
				if IsServer() then 
					EmitSoundOn( "DOTA_Item.BlackKingBar.Activate", self:GetParent() )
					self:GetParent():AddNewModifier( self:GetParent(), nil, "status_immune", {duration = 6} )
				end
				self.actualStatusResistance = self.baseStatusResistance
			else
				local statusResistIncrease = self.statusResistIncreasePerTick
				if self:GetParent():IsStunned() or self:GetParent():IsHexed() or self:GetParent():IsFeared() then
					statusResistIncrease = self.statusResistIncreasePerTick * 1.5
				elseif self:GetParent():IsSilenced() or self:GetParent():IsDisarmed() then
					statusResistIncrease = self.statusResistIncreasePerTick * 1.25
				end
				self.actualStatusResistance = math.min( self.actualStatusResistance + statusResistIncrease, MAX_STATUS_RESIST )
			end
		elseif self.baseStatusResistance < self.actualStatusResistance then
			self.actualStatusResistance = math.max( self.actualStatusResistance - self.statusResistIncreasePerTick, self.baseStatusResistance )
		end
	end
end

function bossPowerScale:CheckState()
	local states = {}
	if self.treewalk  then
		states[MODIFIER_STATE_ALLOW_PATHING_THROUGH_TREES] = true
	end
	if self:GetParent():IsConsideredHero() then
		states[MODIFIER_STATE_NO_HEALTH_BAR] = true
	end
	if self:GetParent():IsHexed() then
		states[MODIFIER_STATE_PASSIVES_DISABLED] = true
	end
	return states
end

function bossPowerScale:GetAttributes()
  return MODIFIER_ATTRIBUTE_PERMANENT + MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE --+ MODIFIER_ATTRIBUTE_MULTIPLE
end

function bossPowerScale:AddCustomTransmitterData()
	return {
		bonusDamage = self.bonusDamage,
		bonusArmor = self.bonusArmor,
		bonusSpellDamage = self.bonusSpellDamage,
		bonusMR = self.bonusMR,
		bonusCooldownReduction = self.bonusCooldownReduction,
		bonusMS = self.bonusMS,
		bossOriginalModel = self.bossOriginalModel,
	}
end

function bossPowerScale:HandleCustomTransmitterData( data )
	self.bonusDamage = data.bonusDamage
	self.bonusArmor = data.bonusArmor
	self.bonusSpellDamage = data.bonusSpellDamage
	self.bonusMR = data.bonusMR
	self.bonusMS = data.bonusMS
	self.bossOriginalModel = data.bossOriginalModel
end

function bossPowerScale:DeclareFunctions()
  local funcs = {
	MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
	MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
	MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
	MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING,
	MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
	MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	MODIFIER_EVENT_ON_DEATH,
	MODIFIER_EVENT_ON_TAKEDAMAGE,
	MODIFIER_EVENT_ON_ABILITY_START
  }
  return funcs
end

function bossPowerScale:OnAbilityStart(event)
	if event.unit ~= self:GetParent() then return end
	local radius = 64
	local position
	if event.ability:GetCursorTarget() then
		position = event.ability:GetCursorTarget():GetAbsOrigin()
		radius = event.ability:GetCursorTarget():GetPaddedCollisionRadius() + 120
	elseif event.ability:GetCursorTargetingNothing() then
		position = event.unit:GetAbsOrigin()
		radius = event.ability:GetTrueCastRange( ) - event.unit:GetCastRangeBonus()
	else
		position = event.ability:GetCursorPosition()
		radius = event.ability:GetAOERadius( )
	end
	ParticleManager:FireWarningParticle(position, radius)
end

function bossPowerScale:OnDeath(event)
	local parent = self:GetParent()
	if event.unit:IsRealHero() and parent:HasModifier("modifier_boss_enraged") then
		local enrage = parent:FindModifierByName("modifier_boss_enraged")
		if not event.unit:IsReincarnating() or enrage:GetStackCount() == 1 then
			enrage:Destroy()
			self.enrageTimer = 90
			self.lastHPPctSinceCheck = self:GetParent():GetHealthPercent()
		else
			enrage:DecrementStackCount()
		end
		self.dmgTakenSinceCheck = 0
	end
end

function bossPowerScale:OnTakeDamage(event)
	local parent = self:GetParent()
	if event.unit == parent and parent:HasModifier("modifier_boss_enraged") then -- taking damage
		self.dmgTakenSinceCheck = (self.dmgTakenSinceCheck or 0) + event.damage
		if self.dmgTakenSinceCheck >= (self:GetParent():GetMaxHealth() * self.HPRageThreshold * 2) / 100 then
			local enrage = parent:FindModifierByName("modifier_boss_enraged")
			local stacksToRemove = math.floor( self.dmgTakenSinceCheck / ((self:GetParent():GetMaxHealth() * self.HPRageThreshold * 2) / 100) )
			if enrage:GetStackCount() > stacksToRemove then
				enrage:SetStackCount( enrage:GetStackCount() - stacksToRemove )
			else
				enrage:Destroy()
			end
			self.dmgTakenSinceCheck = 0
			self.enrageTimer = 30
			self.lastHPPctSinceCheck = self:GetParent():GetHealthPercent()
		end
		
	end
end

function bossPowerScale:GetModifierPhysicalArmorBonus(event)
	return self.bonusArmor
end

function bossPowerScale:GetModifierMoveSpeedBonus_Percentage(event)
	return self.bonusMS
end

function bossPowerScale:GetModifierMagicalResistanceBonus(event)
	return self.bonusMR
end

function bossPowerScale:GetModifierPreAttack_BonusDamage(event)
	return self.bonusDamage
end

function bossPowerScale:GetModifierSpellAmplify_Percentage(event)
	return self.bonusSpellDamage
end

function bossPowerScale:GetModifierStatusResistanceStacking(event)
	return self.actualStatusResistance
end

function bossPowerScale:GetModifierPercentageCooldown(event)
	return self.bonusCooldownReduction
end

function bossPowerScale:IsHidden()
  return true --change that to true when finished debuging
end

function bossPowerScale:IsDebuff()
  return false
end

function bossPowerScale:IsPurgable()
  return false
end

function bossPowerScale:RemoveOnDeath()
	return true
end