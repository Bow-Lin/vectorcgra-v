# VectorCGRA4x4 mapped area breakdown

Flow: Hierarchy-preserving diagnostic mapping

Total area: **3272792.978000** Liberty area units; mapped cells: **2,063,725**.

All percentages use this netlist's complete top-level leaf-cell area. A separately flattened mapping is a separate measurement.

Categories are disjoint and sum to total. Parent groups also sum to total; do not add parent groups to categories. Instance owner areas are disjoint; module_instances subtree areas overlap.

## Disjoint component categories

| Component | Area | Share | Mapped cells |
|---|---:|---:|---:|
| Tile FU compute | 454655.712000 | 13.892% | 381,840 |
| Tile routing crossbar | 125747.776000 | 3.842% | 101,072 |
| Tile FU crossbar | 37533.664000 | 1.147% | 29,376 |
| Tile input channels / output LinkOr | 39921.280000 | 1.220% | 15,872 |
| Tile register cluster | 372783.040000 | 11.390% | 182,528 |
| Tile control memory | 230419.840000 | 7.040% | 93,376 |
| Tile constant memory | 30460.192000 | 0.931% | 11,776 |
| Tile other logic | 11035.808000 | 0.337% | 11,792 |
| CGRA control ring | 1799792.176000 | 54.993% | 1,150,203 |
| CGRA data memory | 65778.608000 | 2.010% | 36,751 |
| CGRA controller | 102897.046000 | 3.144% | 48,479 |
| CGRA top / other logic | 1767.836000 | 0.054% | 660 |
| **Total** | **3272792.978000** | **100%** | **2,063,725** |

## Parent groups (alternative aggregation)

| Group | Area | Share | Mapped cells |
|---|---:|---:|---:|
| tiles | 1302557.312000 | 39.800% | 827,632 |
| ctrl_ring | 1799792.176000 | 54.993% | 1,150,203 |
| data_mem | 65778.608000 | 2.010% | 36,751 |
| controller | 102897.046000 | 3.144% | 48,479 |
| top_other | 1767.836000 | 0.054% | 660 |

## Representative component instances

Equal module types are grouped. Area ranges describe owned logic per instance; tile_other and top_other exclude separately attributed children.

| Component | Instances | Total area | Per-instance area range | Example |
|---|---:|---:|---:|---|
| const_mem | 16 | 30460.192000 | 1903.762000–1903.762000 | `VectorCGRA4x4/tile__0/const_mem` |
| controller | 1 | 102897.046000 | 102897.046000–102897.046000 | `VectorCGRA4x4/controller` |
| ctrl_mem | 16 | 230419.840000 | 14401.240000–14401.240000 | `VectorCGRA4x4/tile__0/ctrl_mem` |
| ctrl_ring | 1 | 1799792.176000 | 1799792.176000–1799792.176000 | `VectorCGRA4x4/ctrl_ring` |
| data_mem | 1 | 65778.608000 | 65778.608000–65778.608000 | `VectorCGRA4x4/data_mem` |
| fu_crossbar | 16 | 37533.664000 | 2345.854000–2345.854000 | `VectorCGRA4x4/tile__0/fu_crossbar` |
| register_cluster | 16 | 372783.040000 | 23298.940000–23298.940000 | `VectorCGRA4x4/tile__0/register_cluster` |
| routing_crossbar | 16 | 125747.776000 | 7859.236000–7859.236000 | `VectorCGRA4x4/tile__0/routing_crossbar` |
| tile_channels_linkor | 64 | 37027.200000 | 578.550000–578.550000 | `VectorCGRA4x4/tile__0/tile_in_channel__0` |
| tile_channels_linkor | 64 | 2894.080000 | 45.220000–45.220000 | `VectorCGRA4x4/tile__0/tile_out_or_link__0` |
| tile_fu_compute | 16 | 454655.712000 | 28415.982000–28415.982000 | `VectorCGRA4x4/tile__0/element` |
| tile_other | 16 | 11035.808000 | 689.738000–689.738000 | `VectorCGRA4x4/tile__0` |
| top_other | 1 | 1767.836000 | 1767.836000–1767.836000 | `VectorCGRA4x4` |
