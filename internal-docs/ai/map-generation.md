# Map Generation

Into the Depths uses a depth-profiled constructive generator. The tile arrays
remain fixed at the save/render maximum (`MAP_WIDTH` x `MAP_HEIGHT`), while the
active generation bounds grow from a smaller shallow mine to the full map at
`MAX_DEPTH`.

## Depth Profiles

`mapgen_bounds_for_depth` returns the active rectangle for a floor:

- Surface: full town map
- Depth 1: compact mine footprint
- Mid depths: gradually wider and taller footprint
- `MAX_DEPTH`: full map footprint

Outside the active rectangle remains solid rock. This keeps save data and render
paths stable while making deeper floors larger and denser.

## Algorithms

The generator layers several deterministic, seed-driven algorithms:

- BSP room partitioning for structured mine rooms and non-overlap.
- Extra room graph cycles so rooms are not only a single linear chain.
- Growing-tree maze spurs from room centers for mine-like side passages.
- Fractal value-noise seeding for broad cave masses.
- Cellular automata smoothing for organic cave edges.
- Drunkard-walk carving for winding caverns and deep-floor erosion.
- Largest-component filtering and farthest-floor descent placement for reliable
  connectivity and objective distance.

## Source Notes

Useful references used for this refactor:

- RogueBasin map-generation index: https://www.roguebasin.com/index.php/Category%3AMaps
- RogueBasin connected cavern notes: https://www.roguebasin.com/index.php/Delving_a_connected_cavern
- Bob Nystrom rooms-and-mazes article: https://journal.stuffwithstuff.com/2014/12/21/rooms-and-mazes/
- PCG book dungeon chapter: https://antoniosliapis.com/articles/pcgbook_dungeons.php
- Cellular automata cave overview: https://blog.jrheard.com/procedural-dungeon-generation-cellular-automata
