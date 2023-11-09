# PolygonGenerator
Godot plugin to automatically create polygons for Polygon2D nodes

## What it is
The Polygon Generator plugin adds a button next to the UV tools for Polygon2D nodes to automatically generate polygons.

## What's next
The otuline finding needs to be slightly improved around corners, so they keep a minimum distance from the opaque part of the texture. Currently this plugin only generates the outline of the image. I still need to add a method to add inner vertices. Also, there should be a way to set parameters for the generator (vertex distance etc.) and select a target area so you can use texture atlases.
