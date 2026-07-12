#!/usr/bin/bash
#
# Website Deployment Packager
# Usage: ./website_packager.sh website/

website="$1"

if [[ -z "$website" || ! -d "$website" ]]; then
    echo "Usage: $0 <website_directory>" >&2
    exit 1
fi

# Spec requirement: if deploy/ already exists, wipe it and start fresh
rm -rf deploy
mkdir -p deploy/assets/{css,js,images}

location="deploy/"

# ---------------------------------------------------------------------
# 1. Copy HTML files to the deploy/ root
#    (find "$website" is used directly everywhere below - no need to
#    strip a trailing slash, find handles that fine on its own)
# ---------------------------------------------------------------------
mapfile -t htmls < <(find "$website" -type f \( -iname "*.html" -o -iname "*.htm" \))

for html in "${htmls[@]}"; do
    newloc="${html##*/}"
    cp "$html" "${location}${newloc}"
done

# ---------------------------------------------------------------------
# 2. Copy CSS files to deploy/assets/css/
# ---------------------------------------------------------------------
mapfile -t csss < <(find "$website" -type f -iname "*.css")

for css in "${csss[@]}"; do
    newloc="assets/css/${css##*/}"
    cp "$css" "${location}${newloc}"
done

# ---------------------------------------------------------------------
# 3. Copy JS files to deploy/assets/js/
# ---------------------------------------------------------------------
mapfile -t jss < <(find "$website" -type f -iname "*.js")

for js in "${jss[@]}"; do
    newloc="assets/js/${js##*/}"
    cp "$js" "${location}${newloc}"
done

# ---------------------------------------------------------------------
# 4. Copy image files to deploy/assets/images/
# ---------------------------------------------------------------------
mapfile -t imgs < <(find "$website" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.svg" \))

for img in "${imgs[@]}"; do
    newloc="assets/images/${img##*/}"
    cp "$img" "${location}${newloc}"
done

# ---------------------------------------------------------------------
# 5. Rewrite internal links inside the deployed HTML files so they
#    point at the new flattened structure. We only need to match on
#    file extension (per the assignment's hint), then rewrite any path
#    ending in that filename to the correct new folder.
# ---------------------------------------------------------------------
mapfile -t deployed_htmls < <(find "$location" -maxdepth 1 -type f \( -iname "*.html" -o -iname "*.htm" \))

for html in "${deployed_htmls[@]}"; do
    # CSS references: anything/anything/name.css -> assets/css/name.css
    sed -i -E 's|([a-zA-Z0-9_./-]*/)?([a-zA-Z0-9_-]+\.css)|assets/css/\2|g' "$html"

    # JS references: anything/anything/name.js -> assets/js/name.js
    sed -i -E 's|([a-zA-Z0-9_./-]*/)?([a-zA-Z0-9_-]+\.js)|assets/js/\2|g' "$html"

    # Image references: anything/anything/name.(jpg|png|gif|svg) -> assets/images/name.ext
    sed -i -E 's#([a-zA-Z0-9_./-]*/)?([a-zA-Z0-9_-]+\.(jpg|png|gif|svg))#assets/images/\2#g' "$html"

    # HTML references: anything/anything/name.html -> name.html (flat, at root)
    sed -i -E 's|([a-zA-Z0-9_./-]*/)?([a-zA-Z0-9_-]+\.html?)|\2|g' "$html"
done

echo "Deployment package built in ${location}"
