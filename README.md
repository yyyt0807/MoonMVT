# MoonMVT

[English package overview](README.mbt.md)

MoonMVT 是纯 MoonBit 实现的 Mapbox Vector Tile 2.1 双向编解码与构建库。它让地图服务、离线地图工具和浏览器/WASM 程序在不引入 JavaScript 运行时或原生 GIS 库的情况下创建、读取、筛选和规范化 MVT 数据。

项目核心处理“瓦片局部整数坐标”。经纬度投影、Web Mercator 瓦片选择、地图下载、渲染和样式均不属于本项目，以避免把格式库变成职责混杂的 GIS 平台。

## 主要能力

- MVT 2.1 `Tile`、`Layer`、`Feature`、`Value` 完整类型模型；
- Point、MultiPoint、LineString、MultiLineString、Polygon/MultiPolygon 命令流；
- 类型化 `LayerBuilder`，自动维护属性键和值字典；
- 有界 Protobuf wire 子集，拒绝截断、溢出、非规范 varint 和非法 wire type；
- 命令语法、属性索引、图层版本、extent 和多边形环方向校验；
- 几何边界、路径数量、点数、环方向及统计分析；
- 按属性、几何类型和瓦片局部范围筛选，并重建紧凑字典；
- 确定性编码和外部瓦片规范化；
- wasm、wasm-gc、JavaScript、Native 四目标检查和测试。

## 安装与验证

发布后可使用 `moon add yyyt0807/moonmvt@0.1.1`。本地仓库执行：

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/build_tile
moon run examples/filter_tile
```

## 行业对标与量化验收

MoonMVT 采用三条独立互操作通道：MoonMVT → Python `mapbox-vector-tile 2.2.0`、Python → MoonMVT，以及 MoonMVT → Mapbox `@mapbox/vector-tile 3.0.0`。测试覆盖 6 类数据、18 个运行时生成向量和 106 个语义断言，发布门槛为 18/18（100%）通过。CI 还对固定 1,000 要素负载执行 100 次编码和解码，要求确定性 100/100、编码结果不超过 25,000 字节、Native release 编解码吞吐均不低于 10,000 要素/秒。

复现方法、逐项失败条件、能力边界和实测基线见[互操作与量化验收](docs/interoperability.md)及[性能基线](docs/benchmarks.md)。这些指标衡量格式语义和 MoonMVT 自身回归，不把不同运行时的耗时直接包装成跨语言速度排名。

## 构建瓦片

```moonbit
let places = @builder.LayerBuilder::new("places")
places.add_points(
  [@model.Point::new(1200, 900)],
  id=Some(1UL),
  properties=[
    @builder.property("name", @model.MvtValue::StringValue("Moon Harbor")),
    @builder.property("capital", @model.MvtValue::BoolValue(true)),
  ],
)
let tile = @builder.TileBuilder::new()
tile.add_built_layer(places)
let bytes = @codec.encode_tile(tile.finish())
let decoded = @codec.decode_tile(bytes)
```

完整程序见 [`examples/build_tile`](examples/build_tile)。

## 几何约定

`add_points` 的一个要素可包含一个或多个点。`add_lines` 接收多条路径，每条至少两个点。`add_polygons` 接收开放环，即结尾不能重复首点；闭合由 `ClosePath` 命令表达。

瓦片坐标 y 轴通常向下，外环必须为屏幕视觉上的顺时针，洞必须为逆时针。MoonMVT 不会静默反转错误方向的环，因为自动修复会掩盖上游几何错误。

```moonbit
land.add_polygons([
  [
    @model.Point::new(100, 100),
    @model.Point::new(3900, 100),
    @model.Point::new(3900, 3900),
    @model.Point::new(100, 3900),
  ],
])
```

## 属性查询和筛选

```moonbit
let capitals = @query.filter_property_equals(
  layer,
  "capital",
  @model.MvtValue::BoolValue(true),
)
let eastern = @query.filter_intersects(
  capitals,
  { min_x: 2048, min_y: 0, max_x: 4096, max_y: 4096 },
)
```

筛选结果会重建属性字典，删除未引用条目。完整程序见 [`examples/filter_tile`](examples/filter_tile)。

## 解码不可信输入

默认限制适合网络传递的常见瓦片。内存受限环境可使用 `DecodeLimits::constrained()`。限制覆盖文档大小、子消息大小、图层/要素/键/值数量、标签数量、几何字数量、字符串字节数和未知字段数。遇到错误时可使用 `MvtError::code()` 获得稳定分类。

## 确定性和规范化

`encode_tile` 固定采用升序字段号、原图层/要素顺序以及字典首次出现顺序。`canonicalize` 会解码并重新编码外部瓦片，删除未知字段并规范字段顺序。

确定性承诺限定为“相同 MoonMVT 模型产生相同字节”，不声称所有符合 MVT 的第三方编码器都会产生相同字节。

## 包结构

| 包 | 职责 |
|---|---|
| `error` | 稳定错误分类 |
| `limits` | 不可信输入资源上限 |
| `wire` | MVT 所需 Protobuf wire 子集 |
| `model` | Tile/Layer/Feature/Value 领域模型 |
| `geometry` | 命令编解码、环方向和几何分析 |
| `codec` | MVT 文档编解码、校验和规范化 |
| `builder` | 类型化要素构建与属性字典管理 |
| `query` | 读取、统计、筛选和安全重建 |

更多信息见 [架构](docs/architecture.md)、[规范符合性](docs/conformance.md)、[互操作与量化验收](docs/interoperability.md)、[性能基线](docs/benchmarks.md)、[安全模型](docs/security.md)、[测试策略](docs/testing.md) 和 [生态查重](docs/ecosystem-comparison.md)。

## 功能边界

MoonMVT 0.1 明确不做：

- 通用 Protocol Buffers runtime 或 IDL 代码生成；
- WGS84/Web Mercator 投影、瓦片覆盖和 GeoJSON；
- 空间索引、数据库、地图服务器、HTTP 或缓存；
- clipping、simplification、拓扑修复和坐标清洗策略；
- Mapbox Style、字体、标注、渲染和交互；
- 栅格瓦片、PMTiles、MBTiles 或 GeoPackage 容器。

## 许可证与来源

源码采用 [Apache License 2.0](LICENSE)。实现根据公开的 [Mapbox Vector Tile 2.1 Specification](https://github.com/mapbox/vector-tile-spec/tree/master/2.1) 独立编写，未复制其他语言 MVT 库源码。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

贡献约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。远程推送与 mooncakes.io 发布是显式的项目所有者操作，清单见 [docs/release-checklist.md](docs/release-checklist.md)。
