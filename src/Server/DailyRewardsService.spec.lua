--!nonstrict
--[[
	@class DailyRewardsService.spec
]]

local require = require(script.Parent.loader).load(script)

local DailyRewardsService = require("DailyRewardsService")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local DEFAULT_CONFIG = {
	ClaimCooldownSeconds = 86400, -- 24 hours
	StreakResetSeconds = 172800, -- 48 hours
}

local function makeMockAdapter(initialData)
	local adapter = {}
	local store = {}

	function adapter:GetClaimData(player)
		if store[player] then
			return store[player]
		end
		return initialData
				and {
					LastClaimTime = initialData.LastClaimTime,
					CurrentDayIndex = initialData.CurrentDayIndex,
				}
			or { LastClaimTime = -1, CurrentDayIndex = 0 }
	end

	function adapter:SetClaimData(player, data)
		store[player] = data
	end

	return adapter
end

-- Creates a fully initialised service with a mock adapter injected before Start.
local function makeService(adapter, config, callbacks)
	local service = setmetatable({}, { __index = DailyRewardsService })
	DailyRewardsService.Init(service, {})
	service._adapter = adapter
	DailyRewardsService.Configure(service, config or DEFAULT_CONFIG, callbacks or { [1] = function() end })
	DailyRewardsService.Start(service)
	return service
end

describe("DailyRewardsService", function()
	describe("CanClaim", function()
		it("should return true for a player who has never claimed", function()
			local service = makeService(makeMockAdapter())
			local mockPlayer = {}
			-- LastClaimTime = -1 means os.time() - (-1) is always >= any reasonable cooldown
			expect(service:CanClaim(mockPlayer)).toBe(true)
		end)

		it("should return false when the cooldown has not elapsed", function()
			local service = makeService(
				makeMockAdapter({ LastClaimTime = os.time(), CurrentDayIndex = 1 }),
				DEFAULT_CONFIG,
				{ [1] = function() end, [2] = function() end }
			)
			local mockPlayer = {}
			expect(service:CanClaim(mockPlayer)).toBe(false)
		end)

		it("should return true once the cooldown has elapsed", function()
			local pastTime = os.time() - DEFAULT_CONFIG.ClaimCooldownSeconds - 1
			local service = makeService(
				makeMockAdapter({ LastClaimTime = pastTime, CurrentDayIndex = 1 }),
				DEFAULT_CONFIG,
				{ [1] = function() end, [2] = function() end }
			)
			local mockPlayer = {}
			expect(service:CanClaim(mockPlayer)).toBe(true)
		end)
	end)

	describe("GetClaimSeconds", function()
		it("should return 0 when the player can claim", function()
			local service = makeService(makeMockAdapter())
			local mockPlayer = {}
			expect(service:GetClaimSeconds(mockPlayer)).toBe(0)
		end)

		it("should return a positive number when the cooldown is still active", function()
			local service = makeService(
				makeMockAdapter({ LastClaimTime = os.time(), CurrentDayIndex = 1 }),
				DEFAULT_CONFIG,
				{ [1] = function() end, [2] = function() end }
			)
			local mockPlayer = {}
			local seconds = service:GetClaimSeconds(mockPlayer)
			expect(seconds).toBeGreaterThan(0)
			expect(seconds).toBeLessThanOrEqualTo(DEFAULT_CONFIG.ClaimCooldownSeconds)
		end)
	end)

	describe("Claim", function()
		it("should call the day's reward callback and advance the index", function()
			local rewardCalled = false
			local callbacks = {
				[1] = function()
					rewardCalled = true
				end,
				[2] = function() end,
			}
			local adapter = makeMockAdapter()
			local service = makeService(adapter, DEFAULT_CONFIG, callbacks)
			local mockPlayer = {}

			service:Claim(mockPlayer)

			expect(rewardCalled).toBe(true)
			expect(adapter:GetClaimData(mockPlayer).CurrentDayIndex).toBe(1)
		end)

		it("should update LastClaimTime to approximately now after a successful claim", function()
			local callbacks = {
				[1] = function() end,
				[2] = function() end,
			}
			local adapter = makeMockAdapter()
			local service = makeService(adapter, DEFAULT_CONFIG, callbacks)
			local mockPlayer = {}
			local before = os.time()

			service:Claim(mockPlayer)

			expect(adapter:GetClaimData(mockPlayer).LastClaimTime).toBeGreaterThanOrEqualTo(before)
		end)

		it("should reset when there is no callback for the next day index", function()
			-- Player is on day 1, but no callback exists for day 2
			local adapter = makeMockAdapter({ LastClaimTime = -1, CurrentDayIndex = 1 })
			local service = makeService(adapter, DEFAULT_CONFIG, { [1] = function() end })
			local mockPlayer = {}

			service:Claim(mockPlayer)

			local data = adapter:GetClaimData(mockPlayer)
			expect(data.CurrentDayIndex).toBe(0)
			expect(data.LastClaimTime).toBe(-1)
		end)
	end)

	describe("Reset", function()
		it("should set CurrentDayIndex to 0 and LastClaimTime to -1", function()
			local adapter = makeMockAdapter({ LastClaimTime = os.time(), CurrentDayIndex = 5 })
			local service = makeService(adapter, DEFAULT_CONFIG, { [1] = function() end })
			local mockPlayer = {}

			service:Reset(mockPlayer)

			local data = adapter:GetClaimData(mockPlayer)
			expect(data.CurrentDayIndex).toBe(0)
			expect(data.LastClaimTime).toBe(-1)
		end)
	end)

	describe("Configure", function()
		it("should error when called after Start", function()
			local service = makeService(makeMockAdapter(), DEFAULT_CONFIG, { [1] = function() end })
			expect(function()
				service:Configure(DEFAULT_CONFIG, { [1] = function() end })
			end).toThrow()
		end)
	end)
end)
