{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module Data.Geometry.Types.Geography where

import qualified Data.Geospatial      as Geospatial
import qualified Data.Vector          as Vector
import qualified Data.Vector.Storable as VectorStorable
import qualified Data.Word            as DataWord
import           Foreign.Storable
import qualified Geography.VectorTile as VectorTile
import           Numeric.Natural      (Natural)
import           Prelude              hiding (Left, Right)

defaultVersion :: DataWord.Word
defaultVersion = 2

-- Pixels
type Pixels = Natural

defaultBuffer :: Pixels
defaultBuffer = 128

-- BoundingBox

data BoundingBox = BoundingBox
  { _bbMinX :: !Double
  , _bbMinY :: !Double
  , _bbMaxX :: !Double
  , _bbMaxY :: !Double
  } deriving (Show, Eq)

data BoundingBoxPts = BoundingBoxPts
  {
    _bbMinPts :: VectorTile.Point
  , _bbMaxPts :: VectorTile.Point
  } deriving (Show, Eq)

data BoundingBoxRect = BoundingBoxRect
  { _left   :: !Int
  , _top    :: !Int
  , _right  :: !Int
  , _bottom :: !Int
  } deriving (Show, Eq)

bboxPtsToBbox :: BoundingBoxPts -> BoundingBox
bboxPtsToBbox (BoundingBoxPts (VectorTile.Point minX minY) (VectorTile.Point maxX maxY)) = BoundingBox (fromIntegral minX) (fromIntegral minY) (fromIntegral maxX) (fromIntegral maxY)

bboxPtsToBboxRect :: BoundingBoxPts -> BoundingBoxRect
bboxPtsToBboxRect (BoundingBoxPts (VectorTile.Point minX minY) (VectorTile.Point maxX maxY)) = BoundingBoxRect minX minY maxX maxY

mkBBoxPoly :: BoundingBox -> Vector.Vector GeoStorableLine
mkBBoxPoly (BoundingBox x1 y1 x2 y2) = pointsToLines $ Vector.fromList [Geospatial.PointXY x1 y1, Geospatial.PointXY x2 y1, Geospatial.PointXY x2 y2, Geospatial.PointXY x1 y2]

pointsToLines :: Vector.Vector Geospatial.PointXY -> Vector.Vector GeoStorableLine
pointsToLines pts = (Vector.zipWith GeoStorableLine <*> Vector.tail) $ Vector.cons (Vector.last pts) pts


-- Coords types

data LatLon = LatLon
  { _llLat :: Double
  , _llLon :: Double }

type ZoomLevel = Natural

type ZoomLevelInt = Int

data CoordsInt = CoordsInt
  { _coordsiX :: Int
  , _coordsiY :: Int
  } deriving (Eq, Show)

data GoogleTileCoordsInt = GoogleTileCoordsInt
  { _gtciZoom   :: ZoomLevelInt
  , _gtciCoords :: CoordsInt
  } deriving (Eq, Show)

mkGoogleTileCoordsInt :: Pixels -> Pixels -> Pixels -> GoogleTileCoordsInt
mkGoogleTileCoordsInt z x y = GoogleTileCoordsInt (toInt z) (CoordsInt (toInt x) (toInt y))

toInt :: Natural -> Int
toInt x = fromIntegral x :: Int

data OutCode = Inside
  | Left
  | Right
  | Bottom
  | Top
  deriving (Eq, Ord, Enum, Bounded, Read, Show)

outCodeToWord8 :: OutCode -> DataWord.Word8
outCodeToWord8 c =
    case c of
      Inside -> 0
      Left   -> 1
      Right  -> 2
      Bottom -> 4
      Top    -> 8

word8ToOutCode :: DataWord.Word8 -> OutCode
word8ToOutCode w =
    case w of
      0 -> Inside
      1 -> Left
      2 -> Right
      4 -> Bottom
      _ -> Top

instance Storable (Double, Double) where
  sizeOf _ = 8 * 2
  alignment _ = 8
  peek p = (,) <$> peekByteOff p 0 <*> peekByteOff p 8
  poke p (a, b) = pokeByteOff p 0 a *> pokeByteOff p 8 b

data ClipPoint = ClipPoint
  { _clipPointCode  :: !OutCode
  , _clipPointPoint :: !VectorTile.Point
  } deriving (Eq, Show)

data ClipLine = ClipLine
  { _clipLine1 :: !ClipPoint
  , _clipLine2 :: !ClipPoint
  }

data GeoClipPoint = GeoClipPoint
  { _geoClipPointCode  :: !OutCode
  , _geoClipPointPoint :: !Geospatial.PointXY
  } deriving (Eq, Show)

data GeoClipLine = GeoClipLine
  { _geoClipLine1 :: !GeoClipPoint
  , _geoClipLine2 :: !GeoClipPoint
  } deriving (Eq, Show)

instance VectorStorable.Storable ClipLine where
  sizeOf _ = (16 * 2) + (1 * 2)
  alignment _ = 8 + 2
  peek p = do
    p1 <- VectorTile.Point <$> peekByteOff p 0 <*> peekByteOff p 8
    p2 <- VectorTile.Point <$> peekByteOff p 16 <*> peekByteOff p 24
    o1 <- peekByteOff p 32
    o2 <- peekByteOff p 33
    pure (ClipLine (ClipPoint (word8ToOutCode o1) p1) (ClipPoint (word8ToOutCode o2) p2))
  poke p (ClipLine (ClipPoint o1 (VectorTile.Point a1 b1)) (ClipPoint o2 (VectorTile.Point a2 b2))) = pokeByteOff p 0 a1 *> pokeByteOff p 8 b1 *> pokeByteOff p 16 a2 *> pokeByteOff p 24 b2 *> pokeByteOff p 32 (outCodeToWord8 o1) *> pokeByteOff p 33 (outCodeToWord8 o2)

data GeoStorableLine = GeoStorableLine
  { _geoStorableLinePt1 :: !Geospatial.PointXY
  , _geoStorableLinePt2 :: !Geospatial.PointXY
  } deriving (Eq, Show)

data StorableLine = StorableLine
  { _storableLinePt1 :: !VectorTile.Point
  , _storableLinePt2 :: !VectorTile.Point
  } deriving (Eq, Show)

instance VectorStorable.Storable StorableLine where
  sizeOf _ = 8 * 2 * 2
  alignment _ = 8
  peek p = do
    p1 <- VectorTile.Point <$> peekByteOff p 0 <*> peekByteOff p 8
    p2 <- VectorTile.Point <$> peekByteOff p 16 <*> peekByteOff p 24
    pure $ StorableLine p1 p2
  poke p (StorableLine (VectorTile.Point a1 b1) (VectorTile.Point a2 b2)) = pokeByteOff p 0 a1 *> pokeByteOff p 8 b1 *> pokeByteOff p 16 a2 *> pokeByteOff p 24 b2
