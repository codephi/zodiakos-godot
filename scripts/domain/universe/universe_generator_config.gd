class_name UniverseGeneratorConfig
extends RefCounted

const Scale = preload("res://scripts/domain/universe/universe_scale.gd")
const GLOBAL_SEED := 0x5A4F4449414B4F53
const GENERATOR_VERSION := 1
const SECTOR_SIZE := Scale.SECTOR_SIZE
const MIN_CLUSTERS := 0
const MAX_CLUSTERS := 2
const MIN_CLUSTER_STARS := 8
const MAX_CLUSTER_STARS := 20
const MIN_CLUSTER_RADIUS := 8.0
const MAX_CLUSTER_RADIUS := 18.0
const MAX_ISOLATED_STARS := 3
const MINIMUM_DISTANCE := 1.5
const MAX_STARS_PER_SECTOR := 64
const VISUAL_TYPES := [&"yellow", &"red", &"white", &"orange", &"blue"]
