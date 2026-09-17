# VectorCGRA4x4 mapped area breakdown

Flow: Hierarchy-preserving diagnostic mapping

Total area: **2049466.692000** Liberty area units; mapped cells: **1,160,207**.

All percentages use this netlist's complete top-level leaf-cell area. A separately flattened mapping is a separate measurement.

Categories are disjoint and sum to total. Parent groups also sum to total; do not add parent groups to categories. Instance owner areas are disjoint; module_instances subtree areas overlap.

## Disjoint component categories

| Component | Area | Share | Mapped cells |
|---|---:|---:|---:|
| Tile FU compute | 454655.712000 | 22.184% | 381,840 |
| Tile routing crossbar | 81681.152000 | 3.985% | 64,432 |
| Tile FU crossbar | 26029.696000 | 1.270% | 18,816 |
| Tile input channels / output LinkOr | 39921.280000 | 1.948% | 15,872 |
| Tile register cluster | 372783.040000 | 18.189% | 182,528 |
| Tile control memory | 230419.840000 | 11.243% | 93,376 |
| Tile constant memory | 30460.192000 | 1.486% | 11,776 |
| Tile other logic | 11035.808000 | 0.538% | 11,792 |
| CGRA control ring | 632451.442000 | 30.859% | 294,168 |
| CGRA data memory | 65778.608000 | 3.210% | 36,751 |
| CGRA controller | 102482.086000 | 5.000% | 48,196 |
| CGRA top / other logic | 1767.836000 | 0.086% | 660 |
| **Total** | **2049466.692000** | **100%** | **1,160,207** |

## Parent groups (alternative aggregation)

| Group | Area | Share | Mapped cells |
|---|---:|---:|---:|
| tiles | 1246986.720000 | 60.844% | 780,432 |
| ctrl_ring | 632451.442000 | 30.859% | 294,168 |
| data_mem | 65778.608000 | 3.210% | 36,751 |
| controller | 102482.086000 | 5.000% | 48,196 |
| top_other | 1767.836000 | 0.086% | 660 |

## Representative component instances

Equal module types are grouped. Area ranges describe owned logic per instance; tile_other and top_other exclude separately attributed children.

| Component | Instances | Total area | Per-instance area range | Example |
|---|---:|---:|---:|---|
| const_mem | 16 | 30460.192000 | 1903.762000–1903.762000 | `VectorCGRA4x4/tile__0/const_mem` |
| controller | 1 | 102482.086000 | 102482.086000–102482.086000 | `VectorCGRA4x4/controller` |
| ctrl_mem | 16 | 230419.840000 | 14401.240000–14401.240000 | `VectorCGRA4x4/tile__0/ctrl_mem` |
| ctrl_ring | 1 | 632451.442000 | 632451.442000–632451.442000 | `VectorCGRA4x4/ctrl_ring` |
| data_mem | 1 | 65778.608000 | 65778.608000–65778.608000 | `VectorCGRA4x4/data_mem` |
| fu_crossbar | 16 | 26029.696000 | 1626.856000–1626.856000 | `VectorCGRA4x4/tile__0/fu_crossbar` |
| register_cluster | 16 | 372783.040000 | 23298.940000–23298.940000 | `VectorCGRA4x4/tile__0/register_cluster` |
| routing_crossbar | 16 | 81681.152000 | 5105.072000–5105.072000 | `VectorCGRA4x4/tile__0/routing_crossbar` |
| tile_channels_linkor | 64 | 37027.200000 | 578.550000–578.550000 | `VectorCGRA4x4/tile__0/tile_in_channel__0` |
| tile_channels_linkor | 64 | 2894.080000 | 45.220000–45.220000 | `VectorCGRA4x4/tile__0/tile_out_or_link__0` |
| tile_fu_compute | 16 | 454655.712000 | 28415.982000–28415.982000 | `VectorCGRA4x4/tile__0/element` |
| tile_other | 16 | 11035.808000 | 689.738000–689.738000 | `VectorCGRA4x4/tile__0` |
| top_other | 1 | 1767.836000 | 1767.836000–1767.836000 | `VectorCGRA4x4` |
