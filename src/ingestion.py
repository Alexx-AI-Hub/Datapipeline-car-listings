"""Fetch car ads through BlocketAPI for selected regions and car makes.

Handle pagination, retries on read timeouts, and filtering by a 24-hour window.
Return ad objects without modification or deduplication. run_ingestion.py coordinates
fetching and saving.
"""

import logging
import time
from datetime import UTC, datetime, timedelta

import httpx
from blocket_api import BlocketAPI, CarModel, CarSortOrder, Location

ALL_REGIONS = list(Location)
ALL_CAR_MAKES = list(CarModel)
logger = logging.getLogger(__name__)


def search_car_with_retry(api: BlocketAPI, **kwargs):
    """Return the API response, retrying up to three times on httpx.ReadTimeout.

    Wait five seconds between attempts. Raise RuntimeError after the third
    read timeout. Propagate other errors immediately. Forward kwargs to
    api.search_car.
    """
    for attempt in range(1, 4):
        try:
            return api.search_car(**kwargs)
        except httpx.ReadTimeout as exc:
            if attempt == 3:
                raise RuntimeError("Blocket request failed after 3 attempts") from exc
            logger.warning("Read timeout; attempt %s/3 failed, retrying in 5s", attempt)
            time.sleep(5)


def _pages(api: BlocketAPI, region: Location, **filters):
    """Yield a list of ads per page, sorted by publication time, newest first.

    Search the given region, passing extra filters to api.search_car.
    Stop on an empty page or when the API indicates the final page.
    """
    page = 1
    while True:
        logger.info("Region %s | filters %s | page %s", region.name, filters, page)
        result = search_car_with_retry(
            api, page=page, sort_order=CarSortOrder.PUBLISHED_DESC,
            locations=[region], **filters,
        )
        cars = result["docs"]
        if not cars:
            return

        # NOT IN USE!!!!
        # Adds region name to each row based on region-ID Metadata
        #for car in cars: 
        #    car["search_region"] = region.name.lower()
        
        yield cars
        if result["metadata"]["is_end_of_paging"]:
            return
        page += 1


def get_cars_for_datetime(regions: list[Location], target_datetime: datetime):
    """Return ads in regions for the 24 hours preceding target_datetime.

    target_datetime must include a timezone; otherwise, raise ValueError.
    Compare each ad's timestamp as Unix time in milliseconds, including the
    start boundary and excluding the end boundary. Skip ads without a timestamp.

    Stop pagination when the last ad on a page predates the start boundary.
    This assumes the publication sort order follows timestamp.
    """
    if target_datetime.utcoffset() is None:
        raise ValueError("target_datetime must include a timezone")
    end = target_datetime.astimezone(UTC)
    start_ms = int((end - timedelta(hours=24)).timestamp() * 1000)
    end_ms = int(end.timestamp() * 1000)
    api = BlocketAPI()
    cars_for_date = []
    for region in regions:
        for cars in _pages(api, region):
            for car in cars:
                timestamp = car.get("timestamp")
                if timestamp is not None and start_ms <= timestamp < end_ms:
                    cars_for_date.append(car)
            oldest_timestamp = cars[-1].get("timestamp")
            if oldest_timestamp is not None and oldest_timestamp < start_ms:
                break
    return cars_for_date


def get_all_current_cars(regions: list[Location], brands: list[CarModel]):
    """Return current ads for the given regions and brands.

    Read through the last available page for each region and car make
    combination. Collect results in a list without deduplication. Coverage
    depends on the selected filters and the API's pagination limits.
    """
    api = BlocketAPI()
    all_cars = []
    for region in regions:
        for brand in brands:
            for cars in _pages(api, region, models=[brand]):
                all_cars.extend(cars)
    return all_cars



