boss_mania_demon_cloak_of_mania = class({})

function boss_mania_demon_cloak_of_mania:GetIntrinsicModifierName()
	return "modifier_boss_mania_demon_cloak_of_mania"
end

modifier_boss_mania_demon_cloak_of_mania = class({})
LinkLuaModifier( "modifier_boss_mania_demon_cloak_of_mania", "bosses/boss_harbingers/boss_mania_demon_cloak_of_mania", LUA_MODIFIER_MOTION_NONE )

function modifier_boss_mania_demon_cloak_of_mania:OnCreated()
	self:OnRefresh()
end

function modifier_boss_mania_demon_cloak_of_mania:OnRefresh()
	self.melancholy_damage_pct = self:GetSpecialValueFor("melancholy_damage_pct") / 100
end

function modifier_boss_mania_demon_cloak_of_mania:DeclareFunctions()
	return {MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE}
end

function modifier_boss_mania_demon_cloak_of_mania:GetModifierIncomingDamage_Percentage( params )
	if self:GetParent():PassivesDisabled() then return end
	if HasBit(params.damage_flags, DOTA_DAMAGE_FLAG_HPLOSS) or HasBit(params.damage_flags, DOTA_DAMAGE_FLAG_REFLECTION) then return end
	if not params.inflictor then return end
	if params.target ~= self:GetParent() then return end
	
	local parent = self:GetParent()
	local ability = self:GetAbility()
	for _, demon in ipairs( parent:FindFriendlyUnitsInRadius( parent:GetAbsOrigin(), -1, {order = FIND_NEAREST} ) ) do
		if demon:GetUnitName() == "npc_dota_boss_dementia_demon" then
			local damage_split = params.damage 
			local enemies = parent:FindEnemyUnitsInRadius( parent:GetAbsOrigin(), -1 )
			local unitCount = 0
			for _, enemy in ipairs( enemies ) do
				if not (enemy == demon or enemy == parent) then
					unitCount = unitCount + 1
				end
			end
			ability:DealDamage( params.attacker, demon, params.damage * self.melancholy_damage_pct, {damage_type = params.damage_type, damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION + DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL + DOTA_DAMAGE_FLAG_REFLECTION} )
			ParticleManager:FireRopeParticle( "particles/units/bosses/boss_dementia_demon_cloak_of_dementia.vpcf", PATTACH_POINT_FOLLOW, parent, demon )
			for _, enemy in ipairs( enemies ) do
				if not (enemy == demon or enemy == parent) then
					ability:DealDamage( parent, enemy, (damage_split * (1-self.melancholy_damage_pct)) / unitCount, {damage_type = params.damage_type, damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION + DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL + DOTA_DAMAGE_FLAG_REFLECTION} )
					ParticleManager:FireRopeParticle( "particles/units/bosses/boss_dementia_demon_cloak_of_dementia.vpcf", PATTACH_POINT_FOLLOW, demon, enemy )
				end
			end
			return -999
		end
	end
end