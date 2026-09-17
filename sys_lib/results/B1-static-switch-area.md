# VectorCGRA4x4 mapped area breakdown

Flow: Hierarchy-preserving diagnostic mapping

Total area: **2104402.342000** Liberty area units; mapped cells: **1,206,277**.

All percentages use this netlist's complete top-level leaf-cell area. A separately flattened mapping is a separate measurement.

Categories are disjoint and sum to total. Parent groups also sum to total; do not add parent groups to categories. Instance owner areas are disjoint; module_instances subtree areas overlap.

## Disjoint component categories

| Component | Area | Share | Mapped cells |
|---|---:|---:|---:|
| Tile FU compute | 454655.712000 | 21.605% | 381,840 |
| Tile routing crossbar | 125747.776000 | 5.975% | 101,072 |
| Tile FU crossbar | 37533.664000 | 1.784% | 29,376 |
| Tile input channels / output LinkOr | 39921.280000 | 1.897% | 15,872 |
| Tile register cluster | 372783.040000 | 17.714% | 182,528 |
| Tile control memory | 230419.840000 | 10.949% | 93,376 |
| Tile constant memory | 30460.192000 | 1.447% | 11,776 |
| Tile other logic | 11035.808000 | 0.524% | 11,792 |
| CGRA control ring | 632451.442000 | 30.054% | 294,168 |
| CGRA data memory | 65778.608000 | 3.126% | 36,751 |
| CGRA controller | 101847.144000 | 4.840% | 47,066 |
| CGRA top / other logic | 1767.836000 | 0.084% | 660 |
| **Total** | **2104402.342000** | **100%** | **1,206,277** |

## Parent groups (alternative aggregation)

| Group | Area | Share | Mapped cells |
|---|---:|---:|---:|
| tiles | 1302557.312000 | 61.897% | 827,632 |
| ctrl_ring | 632451.442000 | 30.054% | 294,168 |
| data_mem | 65778.608000 | 3.126% | 36,751 |
| controller | 101847.144000 | 4.840% | 47,066 |
| top_other | 1767.836000 | 0.084% | 660 |

## Representative component instances

Equal module types are grouped. Area ranges describe owned logic per instance; tile_other and top_other exclude separately attributed children.

| Component | Instances | Total area | Per-instance area range | Example |
|---|---:|---:|---:|---|
| const_mem | 16 | 30460.192000 | 1903.762000–1903.762000 | `VectorCGRA4x4/tile__0/const_mem` |
| controller | 1 | 101847.144000 | 101847.144000–101847.144000 | `VectorCGRA4x4/controller` |
| ctrl_mem | 16 | 230419.840000 | 14401.240000–14401.240000 | `VectorCGRA4x4/tile__0/ctrl_mem` |
| ctrl_ring | 1 | 632451.442000 | 632451.442000–632451.442000 | `VectorCGRA4x4/ctrl_ring` |
| data_mem | 1 | 65778.608000 | 65778.608000–65778.608000 | `VectorCGRA4x4/data_mem` |
| fu_crossbar | 16 | 37533.664000 | 2345.854000–2345.854000 | `VectorCGRA4x4/tile__0/fu_crossbar` |
| register_cluster | 16 | 372783.040000 | 23298.940000–23298.940000 | `VectorCGRA4x4/tile__0/register_cluster` |
| routing_crossbar | 16 | 125747.776000 | 7859.236000–7859.236000 | `VectorCGRA4x4/tile__0/routing_crossbar` |
| tile_channels_linkor | 64 | 37027.200000 | 578.550000–578.550000 | `VectorCGRA4x4/tile__0/tile_in_channel__0` |
| tile_channels_linkor | 64 | 2894.080000 | 45.220000–45.220000 | `VectorCGRA4x4/tile__0/tile_out_or_link__0` |
| tile_fu_compute | 16 | 454655.712000 | 28415.982000–28415.982000 | `VectorCGRA4x4/tile__0/element` |
| tile_other | 16 | 11035.808000 | 689.738000–689.738000 | `VectorCGRA4x4/tile__0` |
| top_other | 1 | 1767.836000 | 1767.836000–1767.836000 | `VectorCGRA4x4` |
