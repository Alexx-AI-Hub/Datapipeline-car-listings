"""Fetch Blocket car ads and save gzip-compressed JSONL files in Data/.

By default, fetch ads whose timestamp falls within the last 24 hours.
Pass end to run() to specify the window's end as a timezone-aware datetime.
Pass all_current=True to fetch current ads by region and car make instead.
The filename date is based on the end time in the Europe/Stockholm timezone.

Run from the project root to fetch the last 24 hours:
    python src/run_ingestion.py

Function call Examples:
    run()
    run(end=datetime(2026, 10, 13, 13, 0, tzinfo=UTC))
    run(all_current=True)
"""

import logging
import time
from datetime import UTC, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import encryption
from ingestion import (
    ALL_CAR_MAKES,
    ALL_REGIONS,
    get_all_current_cars,
    get_cars_for_datetime,
)
from save_list_to_jsongz import save_jsonl_gzip

logger = logging.getLogger(__name__)

def run(end: datetime | None = None, all_current: bool = False) -> Path:
    """Fetch and save ads, returning the output file path.

    Default to the 24 hours preceding the current time. end must include a
    timezone; the start boundary is included and the end boundary is excluded.
    With all_current=True, skip time filtering and use end only for the
    filename date. Replace an existing output file after a successful write.
    """

    if end is None:
        end = datetime.now(UTC)     # Set time here and not in input args.!
    if end.utcoffset() is None:
        raise ValueError("end must include a timezone")
    
    date = end.astimezone(ZoneInfo("Europe/Stockholm")).strftime("%Y_%m_%d")
    
    if all_current:
        cars = get_all_current_cars(ALL_REGIONS, ALL_CAR_MAKES)     # Carmake partition is added as each search cannot exceed 50 pages!
        name = f"blocket_cars_all_current_{date}"
    else:
        cars = get_cars_for_datetime(ALL_REGIONS, end)              # Only Region partition is enough for baily scraping
        name = f"blocket_cars_{date}"


    # Vin and reg-number are pseudonymized for privacy reasons.
    cipher = encryption.get_cipher()
    for car in cars:                                            # Adds encrypted columns for chassi and reg-number
        vin = car.get("chassis_number")
        regno = car.get("regno")

        vin = "".join(vin.split()).upper() if vin else None     # Normalizeremove blanks.  "AB 123 " => "AB123"
        regno = "".join(regno.split()).upper() if regno else None

        car["vin_encrypt"] = encryption.encrypt_value(vin or None, cipher)
        car["regnbr_encrypt"] = encryption.encrypt_value(regno or None, cipher)

    
    return save_jsonl_gzip(cars, name)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s\n")

    start = time.perf_counter()
    try:
        run()
    finally:
        latency = time.perf_counter() - start
        logger.info("Latency: %.3f seconds", latency)

