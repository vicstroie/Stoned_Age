
## ScatterShotCollisionObject is what you will see if your ScatterShotMeshes
## have collision meshes and you call get_collider() in your code. It reports
## both the ScatterShotZone node and the specific ScatterShotMeshes collection
## which contain the object you collided with.
class_name ScatterShotCollisionObject
extends RefCounted

func _init(scatter_zone: ScatterShotZone, collection: ScatterShotMeshes) -> void:
	zone = scatter_zone
	meshes = collection

var zone: ScatterShotZone
var meshes: ScatterShotMeshes
