{-# LANGUAGE FlexibleContexts #-}

-- TODO Change to linear ring.

module Data.Geometry.Clip.Internal.Polygon (
clipPolygon
, clipPolygons
) where

import qualified Data.Vector                   as DataVector
import qualified Data.Vector.Storable          as DataVectorStorable
import qualified Geography.VectorTile          as VectorTile
import qualified Geography.VectorTile          as VG

import qualified Data.Geometry.Types.Geography as TypesGeography

clipPolygons :: TypesGeography.BoundingBoxPts -> DataVector.Vector VectorTile.Polygon -> DataVector.Vector VectorTile.Polygon
clipPolygons bb = DataVector.foldl' addPoly mempty
  where
    addPoly acc f =
      case clipPolygon bb f of
        Nothing -> acc
        Just x  -> DataVector.cons x acc

clipPolygon :: TypesGeography.BoundingBoxPts -> VectorTile.Polygon -> Maybe VectorTile.Polygon
clipPolygon bb poly@(VectorTile.Polygon _ interiors) =
  case clip bb poly of
    Nothing -> Nothing
    Just x  -> Just (VectorTile.Polygon x (clipPolygons bb interiors))

clip :: TypesGeography.BoundingBoxPts -> VectorTile.Polygon -> Maybe (DataVectorStorable.Vector VectorTile.Point)
clip bb poly = checkLength (DataVectorStorable.uniq newClippedPoly)
  where
    newClippedPoly = DataVectorStorable.foldl' foo (VG.polyPoints poly) (TypesGeography.mkBBoxPoly bb)
    checkLength newPoly =
      if DataVectorStorable.length newPoly <= 2
        then Nothing
        else Just (closeIfNot newPoly)

closeIfNot :: DataVectorStorable.Vector VG.Point -> DataVectorStorable.Vector VG.Point
closeIfNot poly =
  if lastPt /= firstPt
    then DataVectorStorable.cons lastPt poly
    else poly
  where
    lastPt = DataVectorStorable.last poly
    firstPt = DataVectorStorable.head poly

foo :: DataVectorStorable.Vector VectorTile.Point -> TypesGeography.ClipLine -> DataVectorStorable.Vector VectorTile.Point
foo polyPts bbLine = if DataVectorStorable.length polyPts <= 2 then DataVectorStorable.empty else newPoints
  where
    newPoints = DataVectorStorable.foldl' (\pts polyLine -> clipEdges polyLine bbLine pts) DataVectorStorable.empty (TypesGeography.pointsToLines polyPts)

clipEdges :: TypesGeography.ClipLine -> TypesGeography.ClipLine -> DataVectorStorable.Vector VectorTile.Point -> DataVectorStorable.Vector VectorTile.Point
clipEdges polyLine@(TypesGeography.ClipLine s e) clipLine acc =
  case (inside e clipLine, inside s clipLine) of
    (True, True)   -> DataVectorStorable.cons e acc
    (True, False)  -> DataVectorStorable.cons e $ DataVectorStorable.cons (lineIntersectPoint clipLine polyLine) acc
    (False, True)  -> DataVectorStorable.cons (lineIntersectPoint clipLine polyLine) acc
    (False, False) -> acc

lineIntersectPoint :: TypesGeography.ClipLine -> TypesGeography.ClipLine -> VectorTile.Point
lineIntersectPoint (TypesGeography.ClipLine (VectorTile.Point x1 y1) (VectorTile.Point x2 y2)) (TypesGeography.ClipLine (VectorTile.Point x1' y1') (VectorTile.Point x2' y2')) =
  let
    (dx, dy) = (x1 - x2, y1 - y2)
    (dx', dy') = (x1' - x2', y1' - y2')
    n1 = (x1 * y2) - (y1 * x2)
    n2 = (x1' * y2') - (y1' * x2')
    d = (dx * dy') - (dy * dx')
    x = ((n1 * dx') - (n2 * dx)) `div` d
    y = ((n1 * dy') - (n2 * dy)) `div` d
  in VectorTile.Point x y

-- Is point of RHS of Line
inside :: VectorTile.Point -> TypesGeography.ClipLine -> Bool
inside (VectorTile.Point x y) (TypesGeography.ClipLine (VectorTile.Point x1 y1) (VectorTile.Point x2 y2)) = (x2 - x1) * (y - y1) > (y2 - y1) * (x - x1)
