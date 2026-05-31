#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import traceback
from typing import Any

DOCUMENT_PREFIX = "検索文書: "
QUERY_PREFIX = "検索クエリ: "
DEFAULT_MODEL = "cl-nagoya/ruri-v3-310m"
MODEL_ALIASES = {
    "ruri-v3-310m": "cl-nagoya/ruri-v3-310m",
    "cl-nagoya/ruri-v3-310m": "cl-nagoya/ruri-v3-310m",
}


def choose_device() -> str | None:
    requested = os.environ.get("GBRAIN_RURI_DEVICE")
    if requested:
        return requested
    try:
        import torch

        if torch.backends.mps.is_available():
            return "mps"
    except Exception:
        pass
    return None


def resolve_model_name(model_id: str) -> str:
    configured = os.environ.get("GBRAIN_RURI_MODEL")
    if configured:
        return configured
    return MODEL_ALIASES.get(model_id, DEFAULT_MODEL)


class RuriWorker:
    def __init__(self, model_name: str) -> None:
        from sentence_transformers import SentenceTransformer

        device = choose_device()
        self.model_name = model_name
        self.model = SentenceTransformer(model_name, device=device) if device else SentenceTransformer(model_name)
        self.batch_size = int(os.environ.get("GBRAIN_RURI_BATCH_SIZE", "32"))

    def embed(self, texts: list[str], input_type: str) -> list[list[float]]:
        prefix = QUERY_PREFIX if input_type == "query" else DOCUMENT_PREFIX
        values = [prefix + (text or "") for text in texts]
        vectors = self.model.encode(
            values,
            batch_size=self.batch_size,
            normalize_embeddings=True,
        )
        return vectors.astype("float32").tolist()


def write_json(payload: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main() -> int:
    worker: RuriWorker | None = None
    loaded_model_name: str | None = None

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            req_id = str(req.get("id") or "")
            model_id = str(req.get("model") or "ruri-v3-310m")
            input_type = str(req.get("input_type") or "document")
            texts = req.get("texts")
            if not req_id:
                raise ValueError("missing id")
            if input_type not in {"document", "query"}:
                raise ValueError(f"unsupported input_type: {input_type}")
            if not isinstance(texts, list) or not all(isinstance(t, str) for t in texts):
                raise ValueError("texts must be a list of strings")

            model_name = resolve_model_name(model_id)
            if worker is None:
                worker = RuriWorker(model_name)
                loaded_model_name = model_name
            elif loaded_model_name != model_name:
                raise ValueError(f"worker already loaded {loaded_model_name}, cannot switch to {model_name}")

            write_json({"id": req_id, "embeddings": worker.embed(texts, input_type)})
        except Exception as exc:
            req_id = ""
            try:
                req_id = str(json.loads(line).get("id") or "")
            except Exception:
                pass
            traceback.print_exc(file=sys.stderr)
            write_json({"id": req_id, "error": str(exc)})

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
