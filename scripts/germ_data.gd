class_name GermData
extends Resource

enum GermTier { LARGE, MEDIUM, SMALL, ELITE, BOSS, BOSS_2, BOSS_3 }

@export var tier: GermTier = GermTier.LARGE
@export var radius: float = 42.0
@export var hp: int = 3
@export var speed_min: float = 48.0
@export var speed_max: float = 76.0
@export var score: int = 100
@export var child_tier: int = GermTier.MEDIUM
@export var child_count: int = 2
@export var fragment_count: int = 3
