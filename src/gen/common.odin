package gen

import gcore "../core"
import eng "../engine"
import gameio "../io"


Content_Manager :: gcore.Content_Manager
Game :: gcore.Game
Room :: gcore.Room
Tile :: gcore.Tile
Tile_Type :: gcore.Tile_Type
Enemy :: gcore.Enemy
Item_Def :: gcore.Item_Def
Ore_Vein :: gcore.Ore_Vein
Vec2 :: gcore.Vec2
Engine_Color :: eng.Engine_Color
MAP_WIDTH :: gcore.MAP_WIDTH
MAP_HEIGHT :: gcore.MAP_HEIGHT
MAX_DEPTH :: gcore.MAX_DEPTH
ITEM_ID_VAULT_KEY :: gcore.ITEM_ID_VAULT_KEY
CARDINAL_DX :: gcore.CARDINAL_DX
CARDINAL_DY :: gcore.CARDINAL_DY

pos_to_idx :: gcore.pos_to_idx
is_walkable :: gcore.is_walkable
enemy_at :: gcore.enemy_at
enemy_occupancy_mark_dirty :: gcore.enemy_occupancy_mark_dirty
item_at :: gcore.item_at
enemy_make_from_def :: gcore.enemy_make_from_def
item_make_from_def :: gcore.item_make_from_def
content_manager_enemy_def :: gcore.content_manager_enemy_def
content_manager_enemy_def_for_depth :: gcore.content_manager_enemy_def_for_depth
content_manager_item_def :: gcore.content_manager_item_def
content_manager_pick_item_def_for_depth :: gcore.content_manager_pick_item_def_for_depth
palette_for_depth :: gcore.palette_for_depth

logger_debugf :: gameio.logger_debugf
rand_room_interior :: gcore.rand_room_interior
rand_room_any :: gcore.rand_room_any
