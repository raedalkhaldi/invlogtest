"""
fetch_data.py - Fetches KSA population data from DataSaudi API
This script fetches 2024 national totals and detailed province-level data,
then saves processed JSON files for the frontend.
"""

import urllib.request
import json
import os
import ssl

DATA_DIR = os.path.join(os.path.dirname(__file__), "static", "data")
os.makedirs(DATA_DIR, exist_ok=True)

# SSL context for HTTPS requests
ctx = ssl.create_default_context()


def fetch_json(url):
    """Fetch JSON from a URL using urllib (no external dependencies)."""
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=30, context=ctx) as resp:
        return json.loads(resp.read().decode("utf-8"))

# API endpoints
NATIONAL_API = (
    "https://api.datasaudi.sa/tesseract/data.jsonrecords"
    "?cube=gastat_population_province_sex_nationality"
    "&locale=ar"
    "&drilldowns=Province%2CSex%2CYear%2CNationality"
    "&measures=Population"
    "&include=Year%3A2024"
    "&limit=100%2C0"
)

DETAILED_API = (
    "https://api.datasaudi.sa/tesseract/data.jsonrecords"
    "?cube=gastat_detailed_population"
    "&locale=ar"
    "&drilldowns=Geography+Province%2CSex%2CYear%2CNationality%2CAge+Range"
    "&measures=Population"
    "&limit=2000%2C0"
)


def fetch_national_data():
    """Fetch 2024 national population totals by gender and nationality."""
    print("Fetching 2024 national data...")
    raw = fetch_json(NATIONAL_API)["data"]

    # Process into structured format
    result = {
        "total_population": 0,
        "saudi": {"male": 0, "female": 0, "total": 0},
        "non_saudi": {"male": 0, "female": 0, "total": 0},
        "by_gender": {"male": 0, "female": 0},
    }

    for record in raw:
        nat = record["Nationality"]
        sex = record["Sex"]
        pop = int(record["Population"])

        if nat == "سعودي":
            if sex == "ذكور":
                result["saudi"]["male"] = pop
            elif sex == "إناث":
                result["saudi"]["female"] = pop
            elif sex == "الإجمالي":
                result["saudi"]["total"] = pop
        elif nat == "غير سعودي":
            if sex == "ذكور":
                result["non_saudi"]["male"] = pop
            elif sex == "إناث":
                result["non_saudi"]["female"] = pop
            elif sex == "الإجمالي":
                result["non_saudi"]["total"] = pop
        elif nat == "الإجمالي":
            if sex == "ذكور":
                result["by_gender"]["male"] = pop
            elif sex == "إناث":
                result["by_gender"]["female"] = pop
            elif sex == "الإجمالي":
                result["total_population"] = pop

    print(f"  Total population: {result['total_population']:,}")
    return result


def fetch_detailed_data():
    """Fetch detailed province-level data with age and nationality breakdowns."""
    print("Fetching detailed province data...")
    all_records = []
    offset = 0
    limit = 500

    while True:
        url = (
            "https://api.datasaudi.sa/tesseract/data.jsonrecords"
            "?cube=gastat_detailed_population"
            "&locale=ar"
            "&drilldowns=Geography+Province%2CSex%2CYear%2CNationality%2CAge+Range"
            "&measures=Population"
            f"&limit={limit}%2C{offset}"
        )
        data = fetch_json(url)
        records = data["data"]
        total = data["page"]["total"]

        all_records.extend(records)
        print(f"  Fetched {len(all_records)}/{total} records...")

        if len(all_records) >= total:
            break
        offset += limit

    # Process by province
    provinces = {}
    age_groups = {}
    province_nationality = {}

    for r in all_records:
        province = r["Geography Province"]
        sex = r["Sex"]
        nationality = r["Nationality"]
        age_range = r["Age Range"]
        pop = int(r["Population"])

        # Skip totals in sex/nationality
        if sex == "الإجمالي" or nationality == "الإجمالي":
            continue

        # Province totals
        if province not in provinces:
            provinces[province] = {"male": 0, "female": 0, "saudi": 0, "non_saudi": 0, "total": 0}
        provinces[province]["total"] += pop
        if sex == "ذكور":
            provinces[province]["male"] += pop
        elif sex == "إناث":
            provinces[province]["female"] += pop
        if nationality == "سعودي":
            provinces[province]["saudi"] += pop
        elif nationality == "غير سعودي":
            provinces[province]["non_saudi"] += pop

        # Age group totals (national)
        if age_range not in age_groups:
            age_groups[age_range] = {"male": 0, "female": 0, "saudi": 0, "non_saudi": 0, "total": 0}
        age_groups[age_range]["total"] += pop
        if sex == "ذكور":
            age_groups[age_range]["male"] += pop
        elif sex == "إناث":
            age_groups[age_range]["female"] += pop
        if nationality == "سعودي":
            age_groups[age_range]["saudi"] += pop
        elif nationality == "غير سعودي":
            age_groups[age_range]["non_saudi"] += pop

    # Sort age groups by Age Range ID
    age_order = [
        "0 - 4", "5 - 9", "10 - 14", "15 - 19", "20 - 24",
        "25 - 29", "30 - 34", "35 - 39", "40 - 44", "45 - 49",
        "50 - 54", "55 - 59", "60 - 64", "65 - 69", "70 - 74",
        "75 - 79", "80+"
    ]
    sorted_ages = {}
    for age in age_order:
        if age in age_groups:
            sorted_ages[age] = age_groups[age]
    # Add any remaining
    for age in age_groups:
        if age not in sorted_ages:
            sorted_ages[age] = age_groups[age]

    # Sort provinces by total population descending
    sorted_provinces = dict(
        sorted(provinces.items(), key=lambda x: x[1]["total"], reverse=True)
    )

    print(f"  Provinces: {len(sorted_provinces)}")
    print(f"  Age groups: {len(sorted_ages)}")

    return {
        "provinces": sorted_provinces,
        "age_groups": sorted_ages,
    }


def main():
    print("=" * 50)
    print("KSA Population Data Fetcher")
    print("=" * 50)

    # Fetch data
    national = fetch_national_data()
    detailed = fetch_detailed_data()

    # Combine all data
    all_data = {
        "national": national,
        "provinces": detailed["provinces"],
        "age_groups": detailed["age_groups"],
        "metadata": {
            "source": "General Authority for Statistics (GASTAT)",
            "api": "https://api.datasaudi.sa",
            "national_year": 2024,
            "detailed_year": 2022,
            "note": "National totals are from 2024. Province and age breakdowns are from the most recent detailed census (2022)."
        }
    }

    # Save to JSON
    output_path = os.path.join(DATA_DIR, "population.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(all_data, f, ensure_ascii=False, indent=2)

    print(f"\nData saved to {output_path}")
    print("Done!")


if __name__ == "__main__":
    main()
