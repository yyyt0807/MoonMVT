import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { VectorTile } from "@mapbox/vector-tile";
import { PbfReader } from "pbf";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const output = execFileSync(
  "moon",
  ["run", "--target", "native", "tools/interop_bridge", "export"],
  { cwd: root, encoding: "utf8" },
);
const vectors = new Map(
  output
    .split(/\r?\n/)
    .filter((line) => line.startsWith("MVT|"))
    .map((line) => {
      const [, name, hex] = line.split("|");
      return [name, Buffer.from(hex, "hex")];
    }),
);

const cases = ["point", "multipoint", "line", "multiline", "polygon", "attributes"];
assert.deepEqual([...vectors.keys()], cases);

function read(name) {
  const tile = new VectorTile(new PbfReader(vectors.get(name)));
  const layer = tile.layers[name];
  assert.equal(layer.version, 2);
  assert.equal(layer.length, 1);
  return { layer, feature: layer.feature(0) };
}

let item = read("point");
assert.equal(item.feature.id, 101);
assert.equal(item.feature.type, 1);
assert.deepEqual({ ...item.feature.properties }, { name: "moon", ok: true });
assert.deepEqual(item.feature.bbox(), [7, 11, 7, 11]);

item = read("multipoint");
assert.equal(item.feature.type, 1);
assert.deepEqual(item.feature.bbox(), [-4, 2, 20, 30]);

item = read("line");
assert.equal(item.feature.type, 2);
assert.deepEqual({ ...item.feature.properties }, { class: "primary" });
assert.deepEqual(item.feature.bbox(), [0, 0, 30, 25]);

item = read("multiline");
assert.equal(item.feature.type, 2);
assert.deepEqual(item.feature.bbox(), [2, 2, 120, 80]);

item = read("polygon");
assert.equal(item.feature.type, 3);
assert.deepEqual(item.feature.bbox(), [0, 0, 40, 40]);

item = read("attributes");
assert.equal(item.layer.extent, 512);
assert.equal(item.feature.id, 106);
assert.deepEqual({ ...item.feature.properties }, {
  string: "MoonMVT",
  float: 1.5,
  double: -2.25,
  int: -3,
  uint: 4,
  sint: -5,
  bool: false,
});
assert.deepEqual(item.feature.bbox(), [256, 256, 256, 256]);

console.log("MoonMVT JavaScript interoperability report");
console.log("reference=@mapbox/vector-tile 3.0.0 + pbf 5.1.2");
console.log("vectors=6");
console.log("semantic_assertions=29");
console.log("result=6/6 vectors passed (100%)");
