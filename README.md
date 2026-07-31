# WooDisplay for macOS

WooDisplay is a compact native macOS studio for turning a WooCommerce product-export CSV into a printable PDF catalogue. The supplied catalogue is bundled into the app, and another WooCommerce export can be loaded at any time with **Import CSV**.

## Launch

Double-click **WooDisplay.app**. The catalogue opens immediately with the supplied product data.

If macOS warns that the app is from an unidentified developer, Control-click the app, choose **Open**, then confirm **Open**. The app is built locally and is not code-signed for public distribution.

## Features

- Shows published WooCommerce products and combines product variations into their parent product
- Live US Letter preview of the PDF output
- Starts with only product image, product name, and price
- Optional SKU, category, stock, brand, and description fields
- Category-grouped page sections with live page ranges and manual category ordering
- Product ordering by category, name, or price
- Click any preview product to omit it, with individual or bulk restore controls
- Adjustable 6, 9, 12, or 16 products per page
- Four preset designs: Studio, Editorial, Poster, and Gallery
- Thirteen font choices
- Custom accent, page, text, price, card, and image-background colors
- Adjustable alignment, image fit, card corners, borders, and spacing
- Import another WooCommerce CSV from inside the app
- Export the previewed design as a printable PDF catalogue

## Create a printable catalogue

Adjust the content, density, theme, colors, and font in the inspector. The large page preview updates immediately. Click **Export PDF**, choose a destination, and the app creates the complete catalogue using the same layout.

## Rebuild

Double-click **Build WooDisplay.command** after changing the source or replacing the CSV. The script compiles a release build and recreates **WooDisplay.app**.

The bundled app is universal for Apple Silicon and Intel Macs and requires macOS 13 or later. Rebuilding requires Apple Command Line Tools with Swift.
