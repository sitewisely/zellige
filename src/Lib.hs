{-# LANGUAGE OverloadedStrings #-}

module Lib where

import           Control.Monad.IO.Class
import           Data.Aeson
import qualified Data.ByteString                 as BS
import qualified Data.ByteString.Lazy            as LBS (ByteString, fromStrict,
                                                         readFile, writeFile)
import           Data.Geography.GeoJSON          as GJ
import           Data.HashMap.Strict             as HM
import           Data.Map.Lazy                   as DMZ
import           Data.Maybe
import           Data.Monoid                     ((<>))
import           Data.Scientific
import           Data.Text                       (Text, pack)
import           Data.Vector                     as DV
import           Data.Vector.Unboxed             as DVU
import           Geography.VectorTile            as V
import           Geography.VectorTile.Geometry   as VG
import           Geography.VectorTile.VectorTile as VT


someFunc :: IO ()
someFunc = putStrLn "someFunc"

writeOut = do
    _ <- BS.writeFile "/tmp/out.mvt" (V.encode $ untile t0)
    pure ()

t0 = VectorTile (DMZ.fromList [(pack "", l0)])
l0 = Layer 2 "water" DV.empty DV.empty (DV.fromList [f0]) 4096
f0 = VT.Feature 0 props pv
props = DMZ.fromList [("uid", I64 123), ("foo", St "bar"), ("cat", St "flew")]
pv = DV.fromList [yyy]
yyy = VG.Polygon xxx DV.empty
xxx = DVU.fromList ([(0, 0), (0,1), (1,1), (1,0), (0,0)] :: [(Int,Int)])

zzz :: IO [GJ.Feature]
zzz = do
    x <- readGeoJson "./test/integration/19781.json"
    pure (features x)

aaa :: IO ([VT.Feature VG.Point], [VT.Feature VG.LineString], [VT.Feature VG.Polygon])
aaa = do
    x <- zzz
    pure (foobar x)

foobar :: [GJ.Feature] -> ([VT.Feature VG.Point], [VT.Feature VG.LineString], [VT.Feature VG.Polygon])
foobar = Prelude.foldr (\x (p, l, o) -> convertFeature p l o x) ([], [], [])

convertFeature p l o (GJ.Feature bb (GJ.Point (GJ.PointGeometry c)) props id) = (VT.Feature 0 (convertProps props) (DV.fromList (moreTerrible c)) : p, l, o)
convertFeature p l o (GJ.Feature bb (GJ.MultiPoint (GJ.MultiPointGeometry mpg)) props id) = (VT.Feature 0 (convertProps props) (DV.fromList (blerg [] mpg)) : p, l, o)
convertFeature p l o (GJ.Feature bb (GJ.LineString ls) props id) = (p, VT.Feature 0 (convertProps props) (DV.fromList (blergLine [] [ls])) : l, o)
convertFeature p l o (GJ.Feature bb (GJ.MultiLineString (GJ.MultiLineStringGeometry mls)) props id) = (p, VT.Feature 0 (convertProps props) (DV.fromList (blergLine [] mls)) : l, o)
convertFeature p l o (GJ.Feature bb (GJ.Polygon poly) props id) = (p, l, VT.Feature 0 (convertProps props) (DV.fromList (blergPoly [] [poly])) : o)
convertFeature p l o (GJ.Feature bb (GJ.MultiPolygon (GJ.MultiPolygonGeometry polys)) props id) = (p, l, VT.Feature 0 (convertProps props) (DV.fromList (blergPoly [] polys)) : o)
convertFeature p l o _ = (p, l, o)

blerg :: [VG.Point] -> [GJ.PointGeometry] -> [VG.Point]
blerg = Prelude.foldr (\pg acc -> moreTerrible (coordinates pg) <> acc)

blergLine :: [VG.LineString] -> [GJ.LineStringGeometry] -> [VG.LineString]
blergLine = Prelude.foldr (\lsg acc -> VG.LineString (DVU.fromList (blerg [] (lineString lsg))) : acc)

blergPoly :: [VG.Polygon] -> [GJ.PolygonGeometry] -> [VG.Polygon]
blergPoly = Prelude.foldr (\poly acc -> VG.Polygon (DVU.fromList (blerg [] (exterior poly))) (DV.fromList (blergPoly [] (Prelude.fmap (\x -> GJ.PolygonGeometry x []) (holes poly)))) : acc)

sToF :: Scientific -> Float
sToF n = toRealFloat n :: Float

fToInt :: Float -> Int
fToInt = round

terrible = fToInt . sToF

convertProps :: Value -> Map Text Val
convertProps (Object x) = DMZ.fromList $ catMaybes $ Prelude.fmap convertElems (HM.toList x)
convertProps _ = DMZ.empty

convertElems (k, String v) = Just (k, St v)
convertElems (k, Number v) = Just (k, Fl (sToF v))
convertElems (k, Bool v) = Just (k, B v)
convertElems (k, v) = Nothing

moreTerrible :: [Scientific] -> [VG.Point]
moreTerrible [] = []
moreTerrible (k:v:t) = (terrible k, terrible v) : moreTerrible t

readGeoJson geoJsonFile = do
    bs <- LBS.readFile geoJsonFile
    let ebs = eitherDecode bs :: Either String GJ.FeatureCollection
        decodeError = error . (("Unable to decode " <> geoJsonFile <> ": ") <>)
    pure (either decodeError id ebs)

emptyLayer = Layer 2 "" DV.empty DV.empty DV.empty 4096
emptyProps = DMZ.empty
emptyPolyon = VG.Polygon (DVU.empty :: DVU.Vector (Int, Int)) DV.empty

