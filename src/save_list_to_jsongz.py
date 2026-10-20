"""Save ad lists as UTF-8 gzip-compressed JSONL in the project's Data/ directory.

Write each ad as a JSON object on its own line. Use a temporary file so that
the destination is replaced only after the entire write completes.
"""

import gzip
import json
import logging
import re
import tempfile
from datetime import datetime
from pathlib import Path

DATA_RAW_DIR = Path(__file__).resolve().parents[1] / "Data"
logger = logging.getLogger(__name__)


def save_jsonl_gzip(cars_list, name: str) -> Path:
    """Save cars_list to Data/{name}.jsonl.gz and return its path.

    name must end with YYYY_MM_DD, optionally preceded by a prefix containing
    ASCII letters, digits, and underscores, separated from the date by an underscore.
    Convert hyphens in the date portion to underscores. Raise ValueError
    for an invalid name or date.

    Create Data/ if needed and replace an existing destination after a
    successful write. Clean up the temporary file even if writing fails.
    """
    name = re.sub(r"(\d{4})-(\d{2})-(\d{2})$", r"\1_\2_\3", name)
    if not re.fullmatch(r"(?:[A-Za-z0-9_]+_)?[0-9]{4}_[0-9]{2}_[0-9]{2}", name):
        raise ValueError(
            "name must end with YYYY_MM_DD and contain only ASCII letters, "
            "digits, or underscores"
        )
    datetime.strptime(name[-10:], "%Y_%m_%d")
    output_dir = Path(DATA_RAW_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{name}.jsonl.gz"
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(dir=output_dir, suffix=".tmp", delete=False) as temp:
            temporary_path = Path(temp.name)
        with gzip.open(temporary_path, "wt", encoding="utf-8") as file:
            for car in cars_list:
                file.write(json.dumps(car, ensure_ascii=False) + "\n")
        temporary_path.replace(output_path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    logger.info("Saved %s cars to %s", len(cars_list), output_path)
    return output_path
