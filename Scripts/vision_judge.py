#!/usr/bin/env python3
"""Headless vision judge for `realityhd gate` (CI, batch runs, second opinions).

Reads out/gate/<id>/report.json (rubric, brief, lint, image metrics) plus sheet.png and, when present,
compare.png and the reference photo; asks Claude to score the rubric; writes out/gate/<id>/verdict.json.
Then: swift run -q realityhd gate <id> --verdict out/gate/<id>/verdict.json --no-sheet [--signoff]

usage: Scripts/vision_judge.py <id> [--model claude-opus-5-5] [--effort high]
needs: pip install anthropic; credentials via ANTHROPIC_API_KEY or `ant auth login`.
"""
import argparse
import base64
import json
import pathlib
import sys

import anthropic

SYSTEM = """You are the quality gate for RealityHD, a library of procedural photoreal 3D assets for
visionOS. You judge renders of one asset against its written brief (and a reference photo when one is
given). Score each rubric criterion 0-10 using its anchors. Be strict and consistent: 8 means a viewer
would accept it as a photograph of the real object at a glance, 10 means indistinguishable up close.
Judge only what the images show. Notes are one short factual line per criterion. Fixes are concrete
edits a programmer can make (part, dimension, material knob, value), most valuable first."""


def image_block(path: pathlib.Path) -> dict:
    media = "image/png" if path.suffix.lower() == ".png" else "image/jpeg"
    data = base64.standard_b64encode(path.read_bytes()).decode("utf-8")
    return {"type": "image", "source": {"type": "base64", "media_type": media, "data": data}}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("id")
    ap.add_argument("--model", default="claude-opus-5-5")
    ap.add_argument("--effort", default="high", choices=["low", "medium", "high", "xhigh", "max"])
    args = ap.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent
    gate = root / "out" / "gate" / args.id
    report = json.loads((gate / "report.json").read_text())
    rubric = report["rubric"]
    ids = [c["id"] for c in rubric]

    content: list[dict] = [{"type": "text", "text": "Six-view contact sheet (stats header on top):"}, image_block(gate / "sheet.png")]
    if (gate / "compare.png").exists():
        content += [{"type": "text", "text": "Reference vs matched render vs silhouette overlay:"}, image_block(gate / "compare.png")]
    brief = report.get("brief") or {}
    for ref in brief.get("references", [])[:2]:
        p = root / ref
        if p.exists():
            content += [{"type": "text", "text": f"Reference photo {ref}:"}, image_block(p)]
    facts = {
        "brief": brief,
        "geometry": {k: report["geometry"][k] for k in ("triangles", "budget", "size", "materials", "issues")},
        "image_metrics": report.get("image"),
        "rubric": rubric,
    }
    content.append({"type": "text", "text": "Facts (JSON):\n" + json.dumps(facts, indent=1) + "\n\nScore every rubric criterion."})

    schema = {
        "type": "object",
        "properties": {
            "scores": {"type": "object", "properties": {i: {"type": "integer"} for i in ids}, "required": ids, "additionalProperties": False},
            "notes": {"type": "object", "properties": {i: {"type": "string"} for i in ids}, "required": ids, "additionalProperties": False},
            "fixes": {"type": "array", "items": {"type": "string"}},
        },
        "required": ["scores", "notes", "fixes"],
        "additionalProperties": False,
    }

    client = anthropic.Anthropic()
    response = client.beta.messages.create(
        model=args.model,
        max_tokens=16000,
        betas=["server-side-fallback-2026-07-01"],
        fallbacks="default",
        system=SYSTEM,
        output_config={"effort": args.effort, "format": {"type": "json_schema", "schema": schema}},
        messages=[{"role": "user", "content": content}],
    )
    if response.stop_reason == "refusal":
        print(f"blocked: judge refused ({response.stop_details})", file=sys.stderr)
        return 2
    text = next(b.text for b in response.content if b.type == "text")
    verdict = json.loads(text)
    verdict["scores"] = {k: max(0, min(10, int(v))) for k, v in verdict["scores"].items()}
    verdict["judge"] = response.model
    (gate / "verdict.json").write_text(json.dumps(verdict, indent=2))
    low = min(verdict["scores"].items(), key=lambda kv: kv[1])
    print(f"{gate / 'verdict.json'} judge {response.model} lowest {low[0]} {low[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
