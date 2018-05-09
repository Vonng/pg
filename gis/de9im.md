## DE9IM





## DE9IM

The “[Dimensionally Extended 9-Intersection Model](http://en.wikipedia.org/wiki/DE-9IM)” (DE9IM) is a framework for modelling how two spatial objects interact.

First, every spatial object has:

- An interior
- A boundary
- An exterior

For polygons, the interior, boundary and exterior are obvious:

The interior is the part bounded by the rings; the boundary is the rings themselves; the exterior is everything else in the plane.

For linear features, the interior, boundary and exterior are less well-known:

The interior is the part of the line bounded by the ends; the boundary is the ends of the linear feature, and the exterior is everything else in the plane.

For points, things are even stranger: the interior is the point; the boundary is the empty set and the exterior is everything else in the plane.

Using these definitions of interior, exterior and boundary, the relationships between any pair of spatial features can be characterized using the dimensionality of the nine possible intersections between the interiors/boundaries/exteriors of a pair of objects.

For the polygons in the example above, the intersection of the interiors is a 2-dimensional area, so that portion of the matrix is filled out with a “2”. The boundaries only intersect at points, which are zero-dimensional, so that portion of the matrix is filled out with a 0.

When there is no intersection between components, the square the matrix is filled out with an “F”.

Here’s another example, of a linestring partially entering a polygon:

The DE9IM matrix for the interaction is this:

Note that the boundaries of the two objects don’t actually intersect at all (the end point of the line interacts with the interior of the polygon, not the boundary, and vice versa), so the B/B cell is filled in with an “F”.

While it’s fun to visually fill out DE9IM matrices, it would be nice if a computer could do it, and that’s what the **ST_Relate** function is for.

The previous example can be simplified using a simple box and line, with the same spatial relationship as our polygon and linestring:

And we can generate the DE9IM information in SQL:

```
SELECT ST_Relate(
         'LINESTRING(0 0, 2 0)',
         'POLYGON((1 -1, 1 1, 3 1, 3 -1, 1 -1))'
       );

```

The answer (1010F0212) is the same as we calculated visually, but returned as a 9-character string, with the first row, second row and third row of the table appended together.

```
101
0F0
212
```

However, the power of DE9IM matrices is not in generating them, but in using them as a matching key to find geometries with very specific relationships to one another.

```
CREATE TABLE lakes ( id serial primary key, geom geometry );
CREATE TABLE docks ( id serial primary key, good boolean, geom geometry );

INSERT INTO lakes ( geom )
  VALUES ( 'POLYGON ((100 200, 140 230, 180 310, 280 310, 390 270, 400 210, 320 140, 215 141, 150 170, 100 200))');

INSERT INTO docks ( geom, good )
  VALUES
        ('LINESTRING (170 290, 205 272)',true),
        ('LINESTRING (120 215, 176 197)',true),
        ('LINESTRING (290 260, 340 250)',false),
        ('LINESTRING (350 300, 400 320)',false),
        ('LINESTRING (370 230, 420 240)',false),
        ('LINESTRING (370 180, 390 160)',false);

```

Suppose we have a data model that includes **Lakes** and **Docks**, and suppose further that Docks must be inside lakes, and must touch the boundary of their containing lake at one end. Can we find all the docks in our database that obey that rule?

Our legal docks have the following characteristics:

- Their interiors have a linear (1D) intersection with the lake interior
- Their boundaries have a point (0D) intersection with the lake interior
- Their boundaries **also** have a point (0D) intersection with the lake boundary
- Their interiors have no intersection (F) with the lake exterior

So their DE9IM matrix looks like this:

So to find all the legal docks, we would want to find all the docks that intersect lakes (a super-set of **potential** candidates we use for our join key), and then find all the docks in that set which have the legal relate pattern.

```
SELECT docks.*
FROM docks JOIN lakes ON ST_Intersects(docks.geom, lakes.geom)
WHERE ST_Relate(docks.geom, lakes.geom, '1FF00F212');

-- Answer: our two good docks

```

Note the use of the three-parameter version of **ST_Relate**, which returns true if the pattern matches or false if it does not. For a fully-defined pattern like this one, the three-parameter version is not needed – we could have just used a string equality operator.

However, for looser pattern searches, the three-parameter allows substitution characters in the pattern string:

- “*” means “any value in this cell is acceptable”
- “T” means “any non-false value (0, 1 or 2) is acceptable”

So for example, one possible dock we did not include in our example graphic is a dock with a two-dimensional intersection with the lake boundary:

```
INSERT INTO docks ( geom, good )
  VALUES ('LINESTRING (140 230, 150 250, 210 230)',true);

```

If we are to include this case in our set of “legal” docks, we need to change the relate pattern in our query. In particular, the intersection of the dock interior lake boundary can now be either 1 (our new case) or F (our original case). So we use the “*” catchall in the pattern.

And the SQL looks like this:

```
SELECT docks.*
FROM docks JOIN lakes ON ST_Intersects(docks.geom, lakes.geom)
WHERE ST_Relate(docks.geom, lakes.geom, '1*F00F212');

-- Answer: our (now) three good docks

```

Confirm that the stricter SQL from the previous example does *not* return the new dock.

## 24.1. Data Quality Testing

The TIGER data is carefully quality controlled when it is prepared, so we expect our data to meet strict standards. For example: no census block should overlap any other census block. Can we test for that?

Sure!

```
SELECT a.gid, b.gid
FROM nyc_census_blocks a, nyc_census_blocks b
WHERE ST_Intersects(a.geom, b.geom)
  AND ST_Relate(a.geom, b.geom, '2********')
  AND a.gid != b.gid
LIMIT 10;

-- Answer: 10, there's some funny business

```

Similarly, we would expect that the roads data is all end-noded. That is, we expect that intersections only occur at the ends of lines, not at the mid-points.

We can test for that by looking for streets that intersect (so we have a join) but where the intersection between the boundaries is not zero-dimensional (that is, the end points don’t touch):

```
SELECT a.gid, b.gid
FROM nyc_streets a, nyc_streets b
WHERE ST_Intersects(a.geom, b.geom)
  AND NOT ST_Relate(a.geom, b.geom, '****0****')
  AND a.gid != b.gid
LIMIT 10;

-- Answer: This happens, so the data is not end-noded.

```

### 24.1.1. Function List

[ST_Relate(geometry A, geometry B)](http://postgis.net/docs/manual-2.1/ST_Relate.html): Returns a text string representing the DE9IM relationship between the geometries.

**Previous**: [23. Linear Referencing](http://workshops.boundlessgeo.com/postgis-intro/linear_referencing.html)

**Next**: [25. Clustering on Indices](http://workshops.boundlessgeo.com/postgis-intro/clusterindex.html)