--!strict
local Players = game:GetService("Players")

--[=[
    System to handle daily rewards in-game

    @server
    @class DailyRewardsService
]=]

local require = require(script.Parent.loader).load(script)

local DailyRewardsAdapter = require("DailyRewardsAdapter")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local DailyRewardsService = {}
DailyRewardsService.ServiceName = "DailyRewardsService"

export type DailyRewardsService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_adapter: DailyRewardsAdapter.DailyRewardsAdapter,
		_rewardCallbacks: { [number]: (Player) -> () },
		_config: DailyRewardsConfig,
		_promiseStarted: Promise.Promise<()>,
	},
	{} :: typeof({ __index = DailyRewardsService })
))

export type DailyRewardsConfig = {
	ClaimCooldownSeconds: number,
	StreakResetSeconds: number,
}

--[=[
	Initializes the DailyRewardsService. Should be done via [ServiceBag.Init].
	@param serviceBag ServiceBag
]=]
function DailyRewardsService.Init(self: DailyRewardsService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External

	-- State
	self._promiseStarted = Promise.new()
	self._adapter = DailyRewardsAdapter.new()
end

--[=[
	Initializes the daily rewards service for players. Should be done via [ServiceBag.Start].
]=]
function DailyRewardsService.Start(self: DailyRewardsService)
	self._promiseStarted:Resolve()

	assert(self._config, "DailyRewardsService was not configured")
	assert(self._rewardCallbacks, "DailyRewardsService reward callbacks were not configured")

	self._maid:Add(Players.PlayerAdded:Connect(function(Player)
		if self:CanClaim(Player) then
			local ClaimData = self:GetState(Player)

			local NextIndex = (ClaimData.CurrentDayIndex :: number) + 1
			if not self._rewardCallbacks[NextIndex] then
				self:Reset(Player)
			end

			if os.time() - ClaimData.LastClaimTime >= self._config.StreakResetSeconds then
				self:Reset(Player)
			end
		end
	end))
end

function DailyRewardsService.Configure(
	self: DailyRewardsService,
	Config: DailyRewardsConfig,
	RewardCallbacks: { [number]: (Player) -> () }
)
	assert(self._promiseStarted, "Not initialized")
	assert(self._promiseStarted:IsPending(), "Already started, cannot configure")

	self._rewardCallbacks = RewardCallbacks
	self._config = Config
end

function DailyRewardsService.CanClaim(self: DailyRewardsService, Player: Player)
	local ClaimData = self:GetState(Player)

	return os.time() - ClaimData.LastClaimTime >= self._config.ClaimCooldownSeconds
end

function DailyRewardsService.GetClaimSeconds(self: DailyRewardsService, Player: Player)
	local ClaimData = self:GetState(Player)
	return math.max(0, (ClaimData.LastClaimTime + self._config.ClaimCooldownSeconds) - os.time())
end

function DailyRewardsService.GetState(self: DailyRewardsService, Player: Player)
	return self._adapter:GetClaimData(Player)
end

function DailyRewardsService.Claim(self: DailyRewardsService, Player: Player)
	local ClaimData = self:GetState(Player)

	local NextIndex = ClaimData.CurrentDayIndex + 1
	local Callback = self._rewardCallbacks[NextIndex]

	if not Callback then
		self:Reset(Player)
	else
		Callback(Player)
		self._adapter:SetClaimData(Player, {
			CurrentDayIndex = NextIndex,
			LastClaimTime = os.time(),
		})
	end
end

function DailyRewardsService.Reset(self: DailyRewardsService, Player: Player)
	self._adapter:SetClaimData(Player, { CurrentDayIndex = 0, LastClaimTime = -1 })
end

function DailyRewardsService.Destroy(self: DailyRewardsService)
	self._maid:DoCleaning()
end

return DailyRewardsService
