{- |
   Module:      Network.SoundCloud.Util
   Copyright:   (c) 2012 Sebastián Ramírez Magrí <sebasmagri@gmail.com>
   License:     BSD3
   Maintainer:  Sebastián Ramírez Magrí <sebasmagri@gmail.com>
   Stability:   experimental

   General functions used by other modules
-}

module Network.SoundCloud.Util where

import Data.List
import Network.HTTP
import System.IO

import Network.SoundCloud.Const

-- | Issue a GET request to an URL and returns
-- the response body as a String or Nothing on failure.
-- If 'followRedirections' is set to True, new requests
-- will be made on 3XX response codes to the Location of
-- the response.
scGet :: String -> Bool -> IO (Maybe String)
scGet url followRedirections =
    do res <- simpleHTTP $ getRequest url
       case res of
         Left   _ -> return Nothing
         Right  r ->
             case rspCode r of
               (2,_,_) -> return $ Just $ rspBody r
               (3,_,_) ->
                   case findHeader HdrLocation r of
                     Nothing       -> return Nothing
                     Just uri      ->
                         if followRedirections
                         then scGet uri True
                         else return $ Just uri
               _ -> return Nothing

-- | Issue a GET request to 'dUrl' and save the response body
-- to a file in the path indicated by the 'out' parameter
scFetch :: String -> String -> IO ()
scFetch dUrl out =
    do contents <- scGet dUrl True
       case contents of
         Nothing -> putStrLn "Could not fetch file contents."
         Just  c ->
             do file <- openBinaryFile out WriteMode
                hPutStr file c
                hClose file

-- | Given an arbitrary resource URL, returns the type of the
-- resource.
-- The response can be one of:
--   "track"
--   "user"
--   "set"
--   "group"
--   "comment"
--   "app"
--   "nothing"
scResourceType :: String -> String
scResourceType url | tracksURL    `isPrefixOf` url      = "track"
                   | usersURL     `isPrefixOf` url      = "user"
                   | playlistsURL `isPrefixOf` url      = "set"
                   | groupsURL    `isPrefixOf` url      = "group"
                   | commentsURL  `isPrefixOf` url      = "comment"
                   | appsURLS     `isPrefixOf` url      = "app"
                   | otherwise                          = "nothing"

{-
This function's request will always return a (3,_,_) status,
so we can just return the redirection Location
-}
-- | Get the API url of a resource given its public URL.
-- In example, for a public URL like:
--     http://soundcloud.com/user/track
-- It returns the API URL:
--     http://api.soundcloud.com/tracks/<track_id>.json?client_id=<foo>
scResolve :: String -> IO String
scResolve url =
    do dat <- scGet resolveUrl False
       case dat of
         Nothing        -> return ""
         Just d         -> return d
    where
        resolveUrl = concat [resolveURL, ".json?url=", url, "&client_id=", clientId]

