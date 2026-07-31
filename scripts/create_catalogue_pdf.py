#!/usr/bin/env python3
"""Create the supplied catalogue PDF for visual QA and immediate use."""

from __future__ import annotations

import csv
import io
import math
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from PIL import Image
from reportlab.lib.colors import Color, HexColor, white
from reportlab.lib.pagesizes import letter
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "wc-product-export-30-7-2026-1785460675095.csv"
OUTPUT_PATH = ROOT / "output" / "pdf" / "WooDisplay-Catalogue.pdf"
CACHE_DIR = ROOT / "tmp" / "pdfs" / "images"

COBALT = HexColor("#0D57E6")
BORDER = HexColor("#E0E3E8")
SECONDARY = HexColor("#626872")
IMAGE_BG = HexColor("#F8F9FB")
GREEN = HexColor("#179B4C")
RED = HexColor("#C74A33")


def clean(value: str | None) -> str:
    return (value or "").strip()


def split_list(value: str | None) -> list[str]:
    return [item.strip() for item in (value or "").split(",") if item.strip()]


def parse_price(value: str | None) -> float | None:
    try:
        return float(clean(value).replace(",", ""))
    except ValueError:
        return None


def load_products() -> list[dict[str, Any]]:
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))

    variations: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        if row.get("Type") == "variation":
            parent = clean(row.get("Parent")).replace("id:", "")
            variations.setdefault(parent, []).append(row)

    products: list[dict[str, Any]] = []
    for row in rows:
        if row.get("Type") == "variation" or row.get("Published") != "1":
            continue

        product_id = clean(row.get("\ufeffID") or row.get("ID"))
        child_rows = variations.get(product_id, [])
        child_prices = [
            price
            for child in child_rows
            if (price := parse_price(child.get("Sale price")) or parse_price(child.get("Regular price")))
            is not None
        ]
        sale_price = parse_price(row.get("Sale price"))
        regular_price = parse_price(row.get("Regular price"))
        low = sale_price or regular_price or (min(child_prices) if child_prices else None)
        high = max(child_prices) if child_prices else low
        if low is None:
            price_label = "Price on request"
        elif high is not None and abs(high - low) > 0.005:
            price_label = f"CA${low:.2f} - CA${high:.2f}"
        else:
            price_label = f"CA${low:.2f}"

        categories = split_list(row.get("Categories"))
        image_urls = split_list(row.get("Images"))
        in_stock = row.get("In stock?") == "1" or any(
            child.get("In stock?") == "1" for child in child_rows
        )

        products.append(
            {
                "id": product_id,
                "name": clean(row.get("Name")) or "Untitled product",
                "sku": clean(row.get("SKU")),
                "price": price_label,
                "category": (
                    categories[0].split(">")[0].strip()
                    if categories
                    else "Uncategorised"
                ),
                "in_stock": in_stock,
                "image_url": image_urls[0] if image_urls else None,
            }
        )

    return sorted(products, key=lambda item: item["name"].casefold())


def image_cache_path(product: dict[str, Any]) -> Path:
    return CACHE_DIR / f"{product['id'] or abs(hash(product['name']))}.jpg"


def download_image(product: dict[str, Any]) -> tuple[str, Path | None]:
    url = product["image_url"]
    if not url:
        return product["id"], None

    destination = image_cache_path(product)
    if destination.exists() and destination.stat().st_size > 100:
        return product["id"], destination

    legacy_source = destination.with_suffix(".img")
    try:
        if legacy_source.exists():
            content = legacy_source.read_bytes()
        else:
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "WooDisplay/1.0"},
            )
            with urllib.request.urlopen(request, timeout=18) as response:
                content = response.read(18_000_001)
        if len(content) > 18_000_000:
            return product["id"], None

        with Image.open(io.BytesIO(content)) as source:
            source.thumbnail((800, 600), Image.Resampling.LANCZOS)
            if source.mode in ("RGBA", "LA") or "transparency" in source.info:
                rgba = source.convert("RGBA")
                normalized = Image.new("RGB", rgba.size, "white")
                normalized.paste(rgba, mask=rgba.getchannel("A"))
            else:
                normalized = source.convert("RGB")
            normalized.save(
                destination,
                format="JPEG",
                quality=82,
                optimize=True,
                progressive=True,
            )
        return product["id"], destination
    except Exception:
        return product["id"], None


def download_images(products: list[dict[str, Any]]) -> dict[str, Path]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    available: dict[str, Path] = {}
    candidates = [product for product in products if product["image_url"]]
    with ThreadPoolExecutor(max_workers=10) as executor:
        jobs = [executor.submit(download_image, product) for product in candidates]
        for index, future in enumerate(as_completed(jobs), start=1):
            product_id, path = future.result()
            if path:
                available[product_id] = path
            if index % 25 == 0 or index == len(jobs):
                print(f"Images: {index}/{len(jobs)}", flush=True)
    return available


def safe_text(value: str) -> str:
    replacements = {
        "\u2013": "-",
        "\u2014": "-",
        "\u2011": "-",
        "\u00a0": " ",
    }
    for source, target in replacements.items():
        value = value.replace(source, target)
    return re.sub(r"\s+", " ", value).strip()


def fit_text(
    value: str,
    font: str,
    size: float,
    max_width: float,
    max_lines: int,
) -> list[str]:
    words = safe_text(value).split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if stringWidth(candidate, font, size) <= max_width:
            current = candidate
            continue
        if current:
            lines.append(current)
        current = word
        if len(lines) == max_lines:
            break
    if current and len(lines) < max_lines:
        lines.append(current)

    was_truncated = len(" ".join(lines)) < len(safe_text(value))
    if was_truncated and lines:
        line = lines[-1]
        while line and stringWidth(f"{line}...", font, size) > max_width:
            line = line[:-1]
        lines[-1] = f"{line.rstrip()}..."
    return lines


def draw_text(
    pdf: canvas.Canvas,
    value: str,
    x: float,
    top: float,
    font: str,
    size: float,
    color: Color,
) -> None:
    pdf.setFont(font, size)
    pdf.setFillColor(color)
    pdf.drawString(x, letter[1] - top - size, safe_text(value))


def draw_image(pdf: canvas.Canvas, path: Path | None, x: float, top: float, width: float, height: float) -> None:
    page_height = letter[1]
    pdf.setFillColor(IMAGE_BG)
    pdf.rect(x, page_height - top - height, width, height, stroke=0, fill=1)
    if not path:
        pdf.setFillColor(HexColor("#9A9FA8"))
        pdf.setFont("Helvetica", 9)
        pdf.drawCentredString(x + width / 2, page_height - top - height / 2 - 3, "No image available")
        return

    try:
        with Image.open(path) as source:
            source_width, source_height = source.size
        scale = min((width - 10) / source_width, (height - 10) / source_height)
        fitted_width = source_width * scale
        fitted_height = source_height * scale
        pdf.drawImage(
            ImageReader(str(path)),
            x + (width - fitted_width) / 2,
            page_height - top - (height + fitted_height) / 2,
            width=fitted_width,
            height=fitted_height,
            preserveAspectRatio=True,
            mask="auto",
        )
    except Exception:
        pdf.setFillColor(HexColor("#9A9FA8"))
        pdf.setFont("Helvetica", 9)
        pdf.drawCentredString(x + width / 2, page_height - top - height / 2 - 3, "No image available")


def draw_product_card(
    pdf: canvas.Canvas,
    product: dict[str, Any],
    path: Path | None,
    x: float,
    top: float,
    width: float,
    height: float,
) -> None:
    page_height = letter[1]
    bottom = page_height - top - height
    pdf.setStrokeColor(BORDER)
    pdf.setLineWidth(0.75)
    pdf.rect(x, bottom, width, height, stroke=1, fill=0)

    image_height = max(24, height - 49)
    draw_image(pdf, path, x, top, width, image_height)

    name_top = top + image_height + 6
    name_lines = fit_text(product["name"], "Helvetica-Bold", 10, width - 12, 2)
    for line_index, line in enumerate(name_lines):
        draw_text(pdf, line, x + 6, name_top + line_index * 12, "Helvetica-Bold", 10, HexColor("#181A1F"))

    price_top = min(top + height - 17, name_top + len(name_lines) * 12 + 1)
    draw_text(pdf, product["price"], x + 6, price_top, "Helvetica-Bold", 10.5, COBALT)


def draw_product_page(
    pdf: canvas.Canvas,
    products: list[dict[str, Any]],
    images: dict[str, Path],
    page_number: int,
    page_count: int,
    category: str,
    first_product: int,
) -> None:
    page_width, page_height = letter
    pdf.setFillColor(white)
    pdf.rect(0, 0, page_width, page_height, stroke=0, fill=1)
    draw_text(
        pdf,
        f"Product Catalogue / {category}",
        30,
        23,
        "Helvetica-Bold",
        17,
        HexColor("#181A1F"),
    )
    pdf.setFillColor(COBALT)
    pdf.roundRect(547, page_height - 36, 35, 5, 2.5, stroke=0, fill=1)

    pdf.setStrokeColor(BORDER)
    pdf.setLineWidth(0.75)
    pdf.line(30, page_height - 57, 582, page_height - 57)

    left = 30
    top = 58
    gap = 10
    row_gap = 10
    card_width = (page_width - left * 2 - gap * 2) / 3
    card_height = (page_height - top - 24 - 11 - row_gap * 3) / 4
    for index, product in enumerate(products):
        column = index % 3
        row = index // 3
        draw_product_card(
            pdf,
            product,
            images.get(product["id"]),
            left + column * (card_width + gap),
            top + row * (card_height + row_gap),
            card_width,
            card_height,
        )

    last_product = first_product + len(products) - 1 if products else 0
    draw_text(pdf, f"{first_product}-{last_product}", 30, 774, "Helvetica-Bold", 8.5, SECONDARY)
    footer = f"{page_number} / {page_count}"
    pdf.setFont("Helvetica-Bold", 8.5)
    pdf.setFillColor(SECONDARY)
    pdf.drawRightString(582, page_height - 774 - 8.5, footer)
    pdf.showPage()


def create_pdf() -> None:
    products = load_products()
    images = download_images(products)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    temporary_output = OUTPUT_PATH.with_suffix(".tmp.pdf")
    pdf = canvas.Canvas(str(temporary_output), pagesize=letter, pageCompression=1)
    pdf.setTitle("Product Catalogue")
    pdf.setAuthor("WooDisplay")
    groups: dict[str, list[dict[str, Any]]] = {}
    for product in products:
        groups.setdefault(product["category"], []).append(product)

    pages: list[tuple[str, list[dict[str, Any]], int]] = []
    first_product = 1
    for category in sorted(groups, key=str.casefold):
        category_products = sorted(groups[category], key=lambda item: item["name"].casefold())
        for start in range(0, len(category_products), 12):
            page_products = category_products[start : start + 12]
            pages.append((category, page_products, first_product + start))
        first_product += len(category_products)

    page_count = max(1, len(pages))
    for page_index, (category, page_products, first_number) in enumerate(pages):
        draw_product_page(
            pdf,
            page_products,
            images,
            page_index + 1,
            page_count,
            category,
            first_number,
        )
    pdf.save()
    temporary_output.replace(OUTPUT_PATH)
    print(f"Created {OUTPUT_PATH}")
    print(f"Products: {len(products)}; images: {len(images)}; pages: {page_count}")


if __name__ == "__main__":
    try:
        create_pdf()
    except Exception as exc:
        print(f"PDF generation failed: {exc}", file=sys.stderr)
        raise
