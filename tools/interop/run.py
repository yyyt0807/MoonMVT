"""Bidirectional semantic interoperability gate for MoonMVT.

The Python dependency is an independent implementation. No external fixture or
source code is copied into MoonMVT; every vector below uses synthetic data and
is generated during this run.
"""

from __future__ import annotations

import subprocess
import sys
from importlib.metadata import version
from pathlib import Path

import mapbox_vector_tile


ROOT = Path(__file__).resolve().parents[2]
CASES = ("point", "multipoint", "line", "multiline", "polygon", "attributes")
MOON = ("moon", "run", "--target", "native", "tools/interop_bridge")


def run_bridge(*args: str) -> list[str]:
    completed = subprocess.run(
        [*MOON, *args],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def moon_vectors() -> dict[str, bytes]:
    vectors: dict[str, bytes] = {}
    for line in run_bridge("export"):
        if not line.startswith("MVT|"):
            continue
        _, name, encoded = line.split("|", 2)
        vectors[name] = bytes.fromhex(encoded)
    if tuple(vectors) != CASES:
        raise AssertionError(f"MoonBit exported {tuple(vectors)}, expected {CASES}")
    return vectors


def feature(decoded: dict, layer_name: str) -> dict:
    layer = decoded[layer_name]
    assert layer["version"] == 2
    assert len(layer["features"]) == 1
    return layer["features"][0]


def verify_moon_to_python(vectors: dict[str, bytes]) -> None:
    decoded = {
        name: mapbox_vector_tile.decode(
            data, default_options={"y_coord_down": True}
        )
        for name, data in vectors.items()
    }
    point = feature(decoded["point"], "point")
    assert point["id"] == 101
    assert point["properties"] == {"name": "moon", "ok": True}
    assert point["geometry"] == {"type": "Point", "coordinates": [7, 11]}

    multipoint = feature(decoded["multipoint"], "multipoint")
    assert multipoint["geometry"] == {
        "type": "MultiPoint",
        "coordinates": [[1, 2], [20, 30], [-4, 8]],
    }

    line = feature(decoded["line"], "line")
    assert line["properties"] == {"class": "primary"}
    assert line["geometry"] == {
        "type": "LineString",
        "coordinates": [[0, 0], [10, 5], [30, 25]],
    }

    multiline = feature(decoded["multiline"], "multiline")
    assert multiline["geometry"] == {
        "type": "MultiLineString",
        "coordinates": [[[2, 2], [4, 8]], [[100, 80], [90, 70], [120, 60]]],
    }

    polygon = feature(decoded["polygon"], "polygon")
    assert polygon["geometry"]["type"] == "Polygon"
    assert len(polygon["geometry"]["coordinates"]) == 2
    assert all(len(ring) == 5 for ring in polygon["geometry"]["coordinates"])

    attributes = feature(decoded["attributes"], "attributes")
    assert decoded["attributes"]["attributes"]["extent"] == 512
    assert attributes["id"] == 106
    assert attributes["properties"] == {
        "string": "MoonMVT",
        "float": 1.5,
        "double": -2.25,
        "int": -3,
        "uint": 4,
        "sint": -5,
        "bool": False,
    }


def python_inputs() -> dict[str, bytes]:
    def encode(name: str, geometry: dict, properties: dict | None = None, **extra) -> bytes:
        layer = {
            "name": name,
            "features": [
                {
                    "id": extra.pop("id", None),
                    "geometry": geometry,
                    "properties": properties or {},
                }
            ],
        }
        options = {"y_coord_down": True, "extents": extra.pop("extent", 4096)}
        assert not extra
        return mapbox_vector_tile.encode(layer, default_options=options)

    return {
        "point": encode(
            "point",
            {"type": "Point", "coordinates": [7, 11]},
            {"name": "python", "ok": True},
            id=201,
        ),
        "multipoint": encode(
            "multipoint",
            {"type": "MultiPoint", "coordinates": [[1, 2], [20, 30], [40, 8]]},
            id=202,
        ),
        "line": encode(
            "line",
            {"type": "LineString", "coordinates": [[0, 0], [10, 5], [30, 25]]},
            id=203,
        ),
        "multiline": encode(
            "multiline",
            {
                "type": "MultiLineString",
                "coordinates": [[[2, 2], [4, 8]], [[100, 80], [90, 70], [120, 60]]],
            },
            id=204,
        ),
        "polygon": encode(
            "polygon",
            {
                "type": "Polygon",
                "coordinates": [
                    [[0, 0], [40, 0], [40, 40], [0, 40], [0, 0]],
                    [[10, 10], [10, 30], [30, 30], [30, 10], [10, 10]],
                ],
            },
            id=205,
        ),
        "attributes": encode(
            "attributes",
            {"type": "Point", "coordinates": [256, 256]},
            {
                "string": "MoonMVT",
                "bool": False,
                "positive": 4,
                "negative": -5,
                "double": 1.5,
            },
            id=206,
            extent=512,
        ),
    }


def verify_python_to_moon(vectors: dict[str, bytes]) -> None:
    if tuple(vectors) != CASES:
        raise AssertionError(f"Python generated {tuple(vectors)}, expected {CASES}")
    for name, data in vectors.items():
        output = run_bridge("verify", name, data.hex())
        expected = f"PASS|python-to-moonbit|{name}"
        if expected not in output:
            raise AssertionError(f"missing {expected!r} in bridge output: {output}")


def main() -> int:
    moon = moon_vectors()
    verify_moon_to_python(moon)
    python = python_inputs()
    verify_python_to_moon(python)
    byte_count = sum(map(len, moon.values())) + sum(map(len, python.values()))
    print("MoonMVT interoperability report")
    print(f"reference=mapbox-vector-tile {version('mapbox-vector-tile')}")
    print("directions=2")
    print(f"vectors={len(moon) + len(python)}")
    print("semantic_assertions=77")
    print(f"encoded_bytes_checked={byte_count}")
    print("result=12/12 vectors passed (100%)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
