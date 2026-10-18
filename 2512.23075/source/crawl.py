#!/usr/bin/env python3
"""Archive the public Notion article and its original image attachments."""
import hashlib
import json
import sys
from pathlib import Path
from urllib.parse import quote

import requests

PAGE_ID = "271211a5-58b7-808d-8b12-d403fd15edda"
BASE = "https://yingru.notion.site"
PAGE_URL = BASE + "/When-Speed-Kills-Stability-Demystifying-RL-Collapse-from-the-Training-Inference-Mismatch-" + PAGE_ID.replace("-", "")
ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "source"
SESSION = requests.Session()


def unwrap(record):
    value = record.get("value", {})
    return value.get("value", value)


def rich_text(items):
    out = []
    for item in items:
        text = item[0]
        for mark in item[1] if len(item) > 1 else []:
            if mark[0] == "e":
                text = "$" + mark[1] + "$"
            elif mark[0] == "a":
                text = "[" + text + "](" + mark[1] + ")"
            elif mark[0] == "lm":
                text = "[" + mark[1].get("title", mark[1]["href"]) + "](" + mark[1]["href"] + ")"
            elif mark[0] == "c":
                text = "`" + text + "`"
            elif mark[0] == "b":
                text = "**" + text + "**"
            elif mark[0] == "i":
                text = "*" + text + "*"
        out.append(text)
    return "".join(out)


def equation_text(items):
    """Notion sometimes embeds an equation in an 'e' rich-text annotation."""
    return "".join(next((mark[1] for mark in (item[1] if len(item) > 1 else []) if mark[0] == "e"), item[0]) for item in items).strip()


def main():
    SOURCE.mkdir(parents=True, exist_ok=True)
    (ROOT / "figures").mkdir(exist_ok=True)
    cursor = {"stack": []}
    blocks = {}
    for n in range(50):
        payload = dict(pageId=PAGE_ID, limit=100, cursor=cursor, chunkNumber=n, verticalColumns=False)
        chunk_path = SOURCE / f"notion-chunk-{n:02d}.json"
        if "--reuse-snapshot" in sys.argv and chunk_path.exists():
            data = json.loads(chunk_path.read_text(encoding="utf-8"))
        else:
            response = SESSION.post(BASE + "/api/v3/loadPageChunk", json=payload, timeout=60)
            response.raise_for_status()
            chunk_path.write_text(response.text, encoding="utf-8")
            data = response.json()
        blocks.update({key: unwrap(value) for key, value in data["recordMap"].get("block", {}).items()})
        cursor = data.get("cursor", {"stack": []})
        print(f"chunk {n}: {len(blocks)} blocks, cursor={bool(cursor.get('stack'))}", flush=True)
        if not cursor.get("stack"):
            break
    else:
        raise RuntimeError("Notion pagination did not finish")

    for n in range(20):
        missing = sorted({child for block in blocks.values() for child in block.get("content", []) if child not in blocks})
        if not missing:
            break
        extra_path = SOURCE / f"notion-extra-{n:02d}.json"
        if "--reuse-snapshot" in sys.argv and extra_path.exists():
            extra = json.loads(extra_path.read_text(encoding="utf-8"))
        else:
            response = SESSION.post(BASE + "/api/v3/getRecordValues", json={"requests": [{"id": block_id, "table": "block"} for block_id in missing]}, timeout=60)
            response.raise_for_status()
            extra_path.write_text(response.text, encoding="utf-8")
            extra = response.json()
        for record in extra["results"]:
            block = unwrap(record)
            if not block.get("id"):
                raise RuntimeError("Cannot retrieve a referenced child block")
            blocks[block["id"]] = block
        print(f"expanded toggles: {len(blocks)} blocks", flush=True)

    ordered = []
    missing = []

    def visit(block_id, depth=0):
        if block_id not in blocks:
            missing.append(block_id)
            return
        block = blocks[block_id]
        compact = {key: block[key] for key in ("id", "type", "properties", "format", "content", "last_edited_time", "file_ids") if key in block}
        compact["depth"] = depth
        ordered.append(compact)
        for child in block.get("content", []):
            visit(child, depth + 1)

    visit(PAGE_ID)
    if missing:
        raise RuntimeError(f"Missing blocks: {missing}")
    (SOURCE / "blocks.json").write_text(json.dumps(ordered, ensure_ascii=False, indent=2), encoding="utf-8")

    old_images = {}
    if "--reuse-snapshot" in sys.argv and (SOURCE / "images.json").exists():
        old_images = {image["block_id"]: image for image in json.loads((SOURCE / "images.json").read_text(encoding="utf-8"))}
    images = []
    for block in ordered:
        if block["type"] != "image":
            continue
        old_image = old_images.get(block["id"])
        if old_image and (ROOT / old_image["path"]).exists():
            content = (ROOT / old_image["path"]).read_bytes()
            if hashlib.sha256(content).hexdigest() == old_image["sha256"]:
                images.append(old_image)
                continue
        image_source = block.get("format", {}).get("display_source") or block["properties"]["source"][0][0]
        url = BASE + "/image/" + quote(image_source, safe="") + "?table=block&id=" + block["id"] + "&cache=v2&width=4000"
        response = SESSION.get(url, timeout=60)
        response.raise_for_status()
        if not response.headers.get("Content-Type", "").startswith("image/"):
            raise RuntimeError(f"Not an image: {url} ({response.headers.get('Content-Type')})")
        extension = ".png" if "png" in response.headers["Content-Type"] else ".jpg"
        name = f"image-{len(images):02d}{extension}"
        (ROOT / "figures" / name).write_bytes(response.content)
        images.append(dict(block_id=block["id"], attachment=image_source, path="figures/" + name, bytes=len(response.content), sha256=hashlib.sha256(response.content).hexdigest(), caption=rich_text(block.get("properties", {}).get("caption", []))))
        print(f"image {name}: {len(response.content)} bytes", flush=True)
    (SOURCE / "images.json").write_text(json.dumps(images, ensure_ascii=False, indent=2), encoding="utf-8")

    image_map = {image["block_id"]: image for image in images}
    markdown = []
    for block in ordered:
        kind = block["type"]
        props = block.get("properties", {})
        title = rich_text(props.get("title", []))
        markdown.append(f"<!-- block:{block['id']} type:{kind} depth:{block['depth']} -->")
        if kind == "image":
            image = image_map[block["id"]]
            markdown.extend([f"![](../{image['path']})", image["caption"]])
        elif kind == "equation":
            markdown.extend(["$$", equation_text(props.get("title", [])), "$$"])
        elif kind == "code":
            markdown.extend(["```" + "".join(item[0] for item in props.get("language", [])), "".join(item[0] for item in props.get("title", [])), "```"])
        elif kind in {"page", "header", "sub_header", "sub_sub_header"}:
            markdown.append({"page": "# ", "header": "## ", "sub_header": "### ", "sub_sub_header": "#### "}[kind] + title)
        elif kind in {"bulleted_list", "numbered_list"}:
            markdown.append("  " * max(block["depth"] - 1, 0) + ("- " if kind == "bulleted_list" else "1. ") + title)
        elif kind == "divider":
            markdown.append("---")
        else:
            markdown.append(title)
            if kind in {"bookmark", "embed", "external_object_instance"}:
                markdown.append(block.get("format", {}).get("uri", "") or json.dumps(props, ensure_ascii=False))
        markdown.append("")
    (SOURCE / "original.en.md").write_text("\n".join(markdown), encoding="utf-8")
    print(f"Archived {len(ordered)} reachable blocks and {len(images)} images", flush=True)


if __name__ == "__main__":
    main()
