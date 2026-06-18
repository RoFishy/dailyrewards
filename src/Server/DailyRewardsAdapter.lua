--[=[
    @class DailyRewardsAdapter
]=]

local _require = require(script.Parent.loader).load(script)

local DailyRewardsAdapter = {}
DailyRewardsAdapter.ClassName = "DailyRewardsAdapter"
DailyRewardsAdapter.__index = DailyRewardsAdapter

export type ClaimData = {
	LastClaimTime: number,
	CurrentDayIndex: number,
}

export type DailyRewardsAdapter = typeof(setmetatable({}, DailyRewardsAdapter)) & {
	GetClaimData: (self: DailyRewardsAdapter, Player: Player) -> ClaimData,
	SetClaimData: (self: DailyRewardsAdapter, Player: Player, Data: ClaimData) -> (),
}

function DailyRewardsAdapter.new(): DailyRewardsAdapter
	local self = setmetatable({}, DailyRewardsAdapter)

	return self :: DailyRewardsAdapter
end

function DailyRewardsAdapter.GetClaimData(_self: DailyRewardsAdapter, _Player: Player): ClaimData
	warn("Configure GetClaimData function within DailyRewardsAdapter")
	return {
		LastClaimTime = -1,
		CurrentDayIndex = 0,
	}
end

function DailyRewardsAdapter.SetClaimData(_self: DailyRewardsAdapter, _Player: Player, _Data: ClaimData): ()
	warn("Configure SetClaimData function within DailyRewardsAdapter")
end

return DailyRewardsAdapter
