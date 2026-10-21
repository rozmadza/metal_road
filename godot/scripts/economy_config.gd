extends Resource
class_name EconomyConfig

@export var starting_credits: int = 2500
@export var vehicle_prices: Dictionary = {
	&"raider": 0,
	&"viper": 2500,
	&"crusher": 4000,
	&"wasteland_gt": 6500,
	&"nomad": 3200,
	&"phantom": 5200,
	&"marauder": 7200,
	&"behemoth": 9000,
	&"dustfox": 5600,
	&"needle": 6900,
	&"warhound": 7900,
	&"bastion": 9800,
}
@export_range(0.0, 1.0, 0.05) var vehicle_sell_ratio: float = 0.6
@export var weapon_prices: Dictionary = {
	&"machine_gun": 0,
	&"heavy_machine_gun": 1200,
	&"shotgun": 1800,
}
@export var race_rewards: Dictionary = {1: 500, 2: 300, 3: 150}
@export var race_kill_reward: int = 75
@export var race_lap_reward: int = 60
@export var damage_reward_per_100: int = 40
@export var survival_kill_reward: int = 100
@export var survival_round_reward: int = 250
@export var survival_victory_reward: int = 500
